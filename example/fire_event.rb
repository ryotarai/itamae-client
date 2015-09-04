require 'openssl'
require 'json'
require 'time'

data = {
  'time' => Time.now.iso8601,
  'dry_run' => false,
  'recipe_uri' => File.join(__dir__, 'recipes.tar.gz'),
  'execution_id' => Time.now.to_i.to_s,
}

secret = "alice"
signature = OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new('sha1'), secret, data.to_json)

payload = "#{data.to_json}|#{signature}"

system "consul", "event", "-name", "itamae-client", payload
