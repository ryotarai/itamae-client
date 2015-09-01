# itamae-client

**This doesn't work yet!**

Welcome to your new gem! In this directory, you'll find the files you need to be able to package up your Ruby library into a gem. Put your Ruby code in the file `lib/itamae/client`. To experiment with that code, run `bin/console` for an interactive prompt.

TODO: Delete this and the text above, and describe your gem

## Installation

    $ gem install itamae-client

## Usage

### Oneshot

```
$ itamae-client apply --tag key1:value1 [--dry-run]
```

### Consul event handler

```
$ consul watch -type event -name itamae \
  consul lock itamae \
  itamae-client consul --server-url http://localhost:3000
```

## Contributing

1. Fork it ( https://github.com/[my-github-username]/itamae-client/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
