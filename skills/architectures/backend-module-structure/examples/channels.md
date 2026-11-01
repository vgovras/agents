# Example: module with vendor channels

Illustrative only. Copy the structure, never the names, logic or values.

```
modules/<domain>/
├── channels/
│   ├── channel.interface
│   ├── <type-1>/<vendor-x>/
│   │   ├── <vendor-x>.types
│   │   ├── <vendor-x>.config
│   │   ├── <vendor-x>.service
│   │   └── <vendor-x>.module
│   └── <type-2>/<vendor-y>/
│       └── ...same files
├── templates/
│   └── <name>.template
├── <domain>.types
├── <domain>.service            # the only file other modules import
└── <domain>.module             # imports vendor modules
```

```
channel.interface
  type
  send(to, message)

<domain>.service
  send(recipient, template, data):
    channel = channels.find(type = pick(recipient))
    message = render(template, channel.type, data)
    channel.send(recipient.address(channel.type), message)
```
