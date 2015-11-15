norma-meteor-run
================

Meteor package for the Norma build tool

To use add the following to your norma.json:

```json
"tasks": {
  "meteor": {
    "src": "out"
  }
}
```

The `src` variable is where your meteor project is located.
This is the directory you would run `meteor run` normally.

It also allows for using settings files

```json

"tasks": {
  "meteor": {
    "src": "out",
    "settings": "settings.json"
  }
}
```


You can reset your meteor instance by running `$ norma meteor reset`
