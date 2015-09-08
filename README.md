# Itamae Client

**This doesn't work yet!**

## Installation

    $ gem install itamae-client

## Usage

### Oneshot mode

```
$ itamae-client apply [--dry-run] [--config config.yml] s3://bucket/key.tar.gz
```

### Consul mode

Itamae Client in Consul mode watches Consul events and runs Itamae.

```
$ itamae-client watch-consul [--config config.yml]
```

#### Event payload

Payload has two part: `JSON|SIGNATURE`

`JSON` is like the following:

```
{"time":"2015-09-03T15:39:52+09:00","recipe":"s3://bucket/key.tar.gz","id":"foobar"}
```

`SIGNATURE` is HMAC SHA1 digest of JSON:

```ruby
OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new('sha1'), secret, json)
```

Example ruby code:

```ruby
require 'openssl'
require 'json'

data = {time: Time.now.iso8601, recipe: "s3://bucket/key.tar.gz"}
secret = "thisisasecret"

sign = OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new('sha1'), secret, data.to_json)
payload = "#{data.to_json}|#{sign}"
puts payload
#=> {"time":"2015-09-03T15:46:06+09:00","recipe":"s3://bucket/key.tar.gz"}|67cadfdeabf14ccac48e553e0af5637b88475899
```

## Configurations

Configurations for Itamae Client is written in YAML.

```yaml
secrets: # required for Consul mode
  - YYY
  - XXX
bootstrap_file: bootstrap.rb # optional (default: bootstrap.rb)
logger:
  - type: stdout
node_json: /path/to/node.json # optional (If this is executable file, stdout result of the executable will be used)
```

See [example configuration](https://github.com/ryotarai/itamae-client/blob/master/example/config.yml) too.

## Contributing

1. Fork it ( https://github.com/ryotarai/itamae-client/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
