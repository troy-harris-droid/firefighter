require 'jwt'

# https://firebase.google.com/docs/auth/admin/create-custom-tokens
module Firefighter
  class TokenGenerator
    def self.from_env
      config = {
        service_account_email: ENV['FIREBASE_SERVICE_ACCOUNT_EMAIL'],
        private_key: OpenSSL::PKey::RSA.new(ENV['FIREBASE_PRIVATE_KEY_DATA']),
        algorithm: 'RS256',
      }
      new(config)
    end

    def initialize(service_account_email:, private_key:, algorithm:)
      @service_account_email = service_account_email
      @private_key = private_key
      @algorithm = algorithm
    end

    def create_token(uid, data: {}, expiration: 60 * 60)
      now_seconds = Time.now.to_i
      payload = {
        iss: @service_account_email,
        sub: @service_account_email,
        aud: 'https://identitytoolkit.googleapis.com/google.identity.identitytoolkit.v1.IdentityToolkit',
        iat: now_seconds,
        exp: now_seconds + expiration, # Maximum expiration time is one hour
        uid: uid,
        data: data,
      }

      ::JWT.encode(payload, @private_key, @algorithm)
    end

    def read_token(token)
      JWT.decode(token, @private_key, true, algorithm: @algorithm).first
    end
  end
end
