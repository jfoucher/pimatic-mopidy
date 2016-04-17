module.exports = (env) ->

  # Require the  bluebird promise library
  Promise = env.require 'bluebird'

  # Require the [cassert library](https://github.com/rhoot/cassert).
  assert = env.require 'cassert'

  M = env.matcher
  _ = env.require('lodash')

  Mopidy = require "mopidy"

  # ###MopidyPlugin class
  class MopidyPlugin extends env.plugins.Plugin


    init: (app, @framework, @config) ->

      deviceConfigDef = require("./device-config-schema")

      @framework.deviceManager.registerDeviceClass("MopidyPlayer", {
        configDef: deviceConfigDef.MopidyPlayer,
        createCallback: (config) => new MopidyPlayer(config)
      })

      #client.on("system", (name) -> console.log "update", name )

  class MopidyPlayer extends env.devices.AVPlayer


    constructor: (@config) ->
      @actions.setVolume=
        description: "set the volume"
        params:
          volume:
            type: String

      @name = @config.name
      @id = @config.id
      @_connect()
      super()

    _connect: () ->
      env.logger.info("Connection to mopidy #{@config.host}:#{@config.port}")
      @_client = new Mopidy {
        webSocketUrl: "ws://#{@config.host}:#{@config.port}/mopidy/ws/",
        callingConvention: "by-position-or-by-name"
      }
#      @_client.on(console.log.bind(console));
      @_client.on('event:playbackStateChanged', (event) =>
        @_setState(event.new_state);
      )
      @_client.on('event:trackPlaybackStarted', (event) =>
        song = event.tl_track?.track
        @_setCurrentTitle(if song.name? then song.name else "")
        @_setCurrentArtist(if song.artists?[0] then song.artists?[0]?.name else "")

      )

      @_connectionPromise = new Promise( (resolve, reject) =>
        onReady = =>
          @_lastError = null
          @_client.off('state:offline', onError)
          resolve()
        onError = (err) =>
          @_client.off('state:online', onReady)
          reject(err)
        @_client.on("state:online", onReady)
        @_client.on("state:offline", onError)
        return
      )

      @_connectionPromise.then( => @_updateInfo() ).catch( (err) =>
        if @_lastError?.message is err.message
          return
        @_lastError = err
        env.logger.error "Error on connecting to mpd: #{err.message}"
        env.logger.debug err.stack
      )
    play: () -> @_client.playback.play()
    pause: () -> @_client.playback.pause()
    stop: () -> @_client.playback.stop()
    previous: () -> @_client.playback.previous()
    next: () -> @_client.playback.next()
    setVolume: (volume) ->
      console.log('volume', volume);
      @_client.mixer.setVolume([volume])
      return Promise.resolve()

    _updateInfo: -> Promise.all([@_getStatus(), @_getCurrentSong()])
    _setState: (state) ->
      switch state
        when 'playing' then state = 'play'
        when 'paused' then state = 'pause'
        when 'stopped' then state = 'stop'

      if @_state isnt state
        @_state = state
        @emit 'state', state

    _getStatus: () ->
      @_client.playback.getState().done((state)=>
        @_setState(state)
      )
      @_client.mixer.getVolume().done((vol)=>
        @_setVolume(vol)
      )

    _getCurrentSong: () ->
      @_client.playback.getCurrentTrack().done((song)=>
        if(song)
          @_setCurrentTitle(if song.name? then song.name else "")
          @_setCurrentArtist(if song.artists?[0] then song.artists?[0]?.name else "")
      )
#      @_client.sendCommandAsync(mpd.cmd("currentsong", [])).then( (msg) =>
#        info = mpd.parseKeyValueMessage(msg)
#        @_setCurrentTitle(if info.Title? then info.Title else "")
#        @_setCurrentArtist(if info.Name? then info.Name else "")
#      ).catch( (err) =>
#        env.logger.error "Error sending mpd command: #{err.message}"
#        env.logger.debug err.stack
#      )
    getCurrentArtist: () -> Promise.resolve(@_currentArtist)
    _sendCommandAction: (action, args...) ->
      return @_connectionPromise.then( =>
        return @_client.sendCommandAsync(mpd.cmd(action, args)).then( (msg) =>
          return
        )
      )

#
#  class MopidyActionProvider extends env.actions.ActionProvider
#
#    constructor: (@framework) ->
## ### executeAction()
#      ###
#      This function handles action in the form of `execute "some string"`
#      ###
#    parseAction: (input, context) =>
#      m = M(input, context)
#      .match(["play music","stop music", "volume"] )
#
#      if m.hadMatch()
#        match = m.getFullMatch()
#        return {
#        token: match
#        nextInput: input.substring(match.length)
#        actionHandler: new MopidyActionHandler(@framework, match)
#        }
#      else
#        return null
#
#
#  class MopidyActionHandler extends env.actions.ActionHandler
#
#    constructor: (@framework, @command) ->
#
#    executeAction: (simulate) =>
#      @framework.variableManager.evaluateStringExpression(@command).then( (command) =>
#        if simulate
#          # just return a promise fulfilled with a description about what we would do.
#          return __("would \"%s\"", command)
#        else
#          console.log(command)
#      )
  # ###Finally
  # Create a instance of my plugin
  mopidyPlugin = new MopidyPlugin
  # and return it to the framework.
  return mopidyPlugin