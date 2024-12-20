# PDX Hackerspace Docker Hackstack

This repo configures a set of services that PDX Hackerspace uses to provide services for its members and for infrastructure, administration and yes, fun and entertainment.

Hackstack uses Docker (with compose) to 

Hackstack's priorities are:
- consistency - all applications follow similar conventions in how
  they are configured, managed, store data and are backed up
- ease of management - Hackstack is meant to be manageable by users
  with basic Linux knowledge and without advanced Docker or
  virtualization environment experience
- low overhead - Hackstack is intended to minimize overhead when
  possible - it should be possible to operate many Hackstack services
  on small computers like a Raspberry Pi
- ease of recovery - Hackstack is designed to make disaster recovery
  easy when possible

- [Philosphy and Design](docs/design.md)
- [Examples](docs/examples.md)
- [Installation](docs/installation.md)
- [Core](docs/core.md)
- [Home Assistant](docs/home-assistant.md)
- [AI](docs/ai.md)
- [Services](docs/services.md)

## Contributing

Please see the [Contributing](docs/contributing.md) guide.

## License

Hackstack is released under the MIT License.
