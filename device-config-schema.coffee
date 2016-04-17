module.exports ={
  title: "pimatic-mopidy device config schemas"
  MopidyPlayer: {
    title: "MopidyPlayer config options"
    type: "object"
    extensions: ["xLink"]
    properties:
      port:
        description: "The port of mpd server"
        type: "number"
      host:
        description: "The address of mpd server"
        type: "string"
      password:
        description: "The password of mpd server"
        type: "string"
  }
}