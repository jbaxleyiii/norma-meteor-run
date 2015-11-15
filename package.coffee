
Path = require "path"
Fs = require "fs"
Ncp = require('ncp').ncp
Rimraf = require "rimraf"
Norma = require "normajs"

Meteor = require "./lib/meteor"

module.exports = (config) ->

  if !config.tasks["meteor-run"]
    return

  cwd = process.cwd()
  _meteor = config.tasks["meteor-run"]

  src = _meteor.src

  # @TODO allow the meteor class to extend these attributes
  Meteor.src = Path.resolve src
  Meteor.cwd = Path.resolve cwd
  Meteor.port = _meteor.port or 3000

  if _meteor.settings
    Meteor.settings = Path.relative Meteor.src, _meteor.settings


  # PACKAGES --------------------------------------------------------------

  prepare = (callback) ->

    if !Fs.existsSync Path.join(src, ".meteor")

      desiredSrc = src
      _tempSrc = "_meteorInstall"
      Meteor.src = process.cwd()

      # ensure no meteor folder exists
      if Fs.existsSync _tempSrc
        Rimraf.sync Path.resolve(_tempSrc)

      Meteor.run "create #{_tempSrc}", true, ->

        copySrc = Path.join _tempSrc, ".meteor"
        destSrc = Path.join desiredSrc, ".meteor"

        if !Fs.existsSync desiredSrc
          Fs.mkdirSync desiredSrc

        Ncp copySrc, destSrc, (err) ->
          if err
            Norma.domain._events.error err

          Rimraf Path.resolve(_tempSrc), ->
            if err
              Norma.domain._events.error err
            return

          Meteor.src = desiredSrc

          callback()


    else
      ready = Prepare _meteor

      ready.then( ->

        callback()

      ).fail( (err) ->

        # Map captured errors back to domain
        Norma.domain._events.error err
      )





  # EVENTS -----------------------------------------------------------------

  Norma.on "watch-start", ->

      # shim for not running meteor but maintaining it
    if _meteor.watch is false
      return

    Norma.execute "meteor"



  Norma.on "close", (cb) ->

    Meteor.end()

    if typeof cb is "function"
      cb null



  # Norma.subscribe "install", (cb) ->
  #
  #   prepare ->
  #
  #     cb null



  # START ------------------------------------------------------------------

  Norma.task "meteor-run-start", (cb) ->


    Meteor.start()

    if typeof cb is "function"
      cb null






  # BUILD ------------------------------------------------------------------

  Norma.task "meteor-run-build", (cb) ->

    prepare ->

      build = Path.resolve cwd, _meteor.build.dest

      if !Fs.existsSync build
        Fs.mkdirSync build

      relativeBuild = Path.resolve src, build

      action = ["build", relativeBuild, "--server", _meteor.build.server]

      Norma.emit "message", "starting build..."

      Meteor.run action, ->

        if typeof cb is "function"
          cb null






  # METEOR -----------------------------------------------------------------

  Norma.task "meteor-run", (cb, tasks) ->

    # make sure meteor is ready to go!
    prepare ->

      # if this is running with advanced tasks
      if tasks

        # custom advanced task to kill meteor
        if tasks[0] is "close"
          Meteor.end cb
          return

        # if we are running meteor, bind meteor running
        # to continue build
        if tasks[0] is "run"
          Norma.on "meteor-ready", ->
            Norma.emit "message", "✔ Meteor running!"

            if typeof cb is "function"
              cb null
            return

        # run all tasks outside of `close`
        Meteor.run tasks, ->

          # only run cb if run wasn't the task
          if typeof cb is "function" and tasks[0] isnt "run"

            cb null

          return

        return

      # no watch, don't run meteor on builds
      if not Norma.watchStarted

        cb null
        return

      # start for the watch task with cb begin run on meteor
      # actually running
      Norma.execute "meteor-start", ->

        Norma.on "meteor-ready", ->
          Norma.emit "message", "✔ Meteor running!"

          if typeof cb is "function"
            cb null

      return

    return






  # Set your file type(s) here
  Norma.tasks["meteor-run"].order = "post"


  # Export all of your tasks
  module.exports.tasks = Norma.tasks
