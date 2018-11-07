require 'jwt'

module Firefighter
  class Identitytoolkit
    include Web

    def self.from_env
      config = {
        api_key: ENV['FIREBASE_WEB_API_KEY'],
        service_account_email: ENV['FIREBASE_SERVICE_ACCOUNT_EMAIL'],
        service_account_private_key_data: ENV['FIREBASE_PRIVATE_KEY_DATA'],
      }
      new(config)
    end

    def initialize(api_key:, service_account_email:, service_account_private_key_data:)
      @api_key = api_key
      @service_account_email = service_account_email
      @service_account_private_key_data = service_account_private_key_data
    end

    def signup(email, password)
      url = endpoint('signupNewUser')
      data = {
        email: email,
        password: password,
        returnSecureToken: true
      }
      call(:post, url, data)
    end

    def account_info(id_token, local_ids: [],	emails: [])
      url = endpoint('getAccountInfo')
      data = {
        idToken: id_token,
        localId: local_ids,
        email: emails,
      }
      call(:post, url, data)
    end

    def download_accounts
      url = endpoint('downloadAccount')

      users = []

      access_token = fetch_access_token
      headers = {Authorization: "Bearer #{access_token}" }
      paginate(url, headers: headers) { |data| users << data['users'] }

      users.flatten.compact
    end

    def fetch_access_token(expiration: 60 * 60)
      now = Time.new
      assertion = {
          'iss' => @service_account_email,
          'scope' => 'https://www.googleapis.com/auth/identitytoolkit',
          'aud' => 'https://accounts.google.com/o/oauth2/token',
          'exp' => (now + expiration).to_i,
          'iat' => now.to_i
      }
      assertion = ::JWT.encode(assertion, OpenSSL::PKey::RSA.new(@service_account_private_key_data), 'RS256')

      url = 'https://accounts.google.com/o/oauth2/token'
      data = {
        assertion: assertion,
        grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer'
      }
      response = call(:post, url, data)
      response['access_token']
    end

    private

    def paginate(url, method: :post, headers: {}, page_size: 100, max_iterations: 1000)
      next_page_token = nil
      max_iterations.times do
        data = {
          nextPageToken: next_page_token,
          maxResults: page_size,
        }
        data = call(method, url, data, headers)

        yield data

        return if data['nextPageToken']&.empty? || data['nextPageToken'] == next_page_token

        next_page_token = data['nextPageToken']
      end
    end

    def endpoint(path)
      "https://www.googleapis.com/identitytoolkit/v3/relyingparty/#{path}?key=#{@api_key}"
    end
  end
end
