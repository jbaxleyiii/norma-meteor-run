Path = require("path")
Spawn = require("child_process").spawn
Exec = require("child_process").exec
_ = require "underscore"
Norma = require "normajs"

Meteor =
  isRunning: false



_bindLogging = (_meteor) ->

  _meteor.stdout.on "data", (data) ->
    msg = data.toString().slice(0, -1)

    Norma.emit "message", msg

    if msg.match /App running/
      Norma.prompt()
      Norma.emit "meteor-ready"

    return


  _meteor.stderr.on "data", (data) ->
    msg = data.toString().slice(0, -1)
    Norma.emit "error", msg
    return



_bindClose = (_meteor, cb) ->



  _meteor.on "close", (code, signal) ->
    Meteor.isRunning = false

    if typeof cb is "function"
      success = code is 0
      if success
        cb null

    if code is not 0
      Norma.emit "error", "Meteor process crashed"
    return



Meteor.run = (task, silent, cb) ->

  if !cb and typeof silent is "function"
    cb = silent
    silent = false


  dir = process.cwd()
  if @.src
    dir = @.src


  cleaned = (if Array.isArray(task) then task else task.split(" "))
  task = (if task then cleaned else [])


  if task[0] is "run" or task[0] is "build" or task[0] is "deploy"
    if Meteor.settings
      task.push "--settings"
      task.push @.settings

    if Norma.production
      task.push "--production"

    task.push "--port"
    task.push @.port



  if task[0] is "mongo"
    stdio = [0, 1]
  else stdio = []

  if @.mongoUrl
    process.env.MONGO_URL = @.mongoUrl

  if @.env
    for envVar, value of @.env
      process.env[envVar] = value



  if @.packageDirs
    existingPackages = []
    packagesCopy = @.packageDirs.slice()

    # if process.env.PACKAGE_DIRS
    #   existingPackages = process.env.PACKAGE_DIRS.split(Path.delimiter)
    #
    # joinedPackageDir = packagesCopy.concat(existingPackages)
    # joinedPackageDir = _.uniq(joinedPackageDir)

    newPackages = (
      Path.relative(dir, packageDir) for packageDir in packagesCopy
    )

    process.env.PACKAGE_DIRS = newPackages.join(Path.delimiter)


  _meteor = Spawn(
    "meteor"
    task
    {
      cwd: dir
      stdio: stdio
      env: process.env
    }
  )

  @.isRunning = true

  if not silent
    _bindLogging _meteor

  _bindClose _meteor, cb

  @.meteor = _meteor

  return



Meteor.start = ->

  if !@.isRunning
    @.run ["run"]


Meteor.end = (callback) ->

  if @.isRunning

    @.meteor.on "close", ->
      callback null
      @.isRunning = false

    @.meteor.kill()







Meteor.add = (type, pkge, cb) ->

  if typeof pkge is "string"
    pkge = [pkge]

  if !@.isRunning

    Norma.emit "message", "Intalling #{type}: #{pkge}"

    switch type
      when "packages"
        @.run ["add"].concat(pkge), cb
      when "platforms"
        @.run ["add-platform"].concat(pkge), cb



Meteor.remove = (type, pkge, cb) ->

  if typeof pkge is "string"
    pkge = [pkge]

  if !@.isRunning

    Norma.emit "message", "Removing #{type}: #{pkge}"
    switch type
      when "packages"
        @.run ["remove"].concat(pkge), cb
      when "platforms"
        @.run ["remove-platform"].concat(pkge), cb




module.exports = Meteor
