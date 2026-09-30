class JsonWebToken
  ALGORITHM = "HS256".freeze
  EXP_DURATION = 2.hours

  class << self
    def encode(payload)
      payload = payload.dup
      payload[:jti] = SecureRandom.uuid
      payload[:exp] = EXP_DURATION.from_now.to_i
      JWT.encode(payload, secret, ALGORITHM)
    end

    def decode(token)
      decoded = JWT.decode(token, secret, true, algorithm: ALGORITHM)[0]
      decoded.with_indifferent_access
      rescue JWT::ExpiredSignature, JWT::DecodeError
      nil
    end

    private

    def secret
      Rails.application.credentials.jwt_secret ||
        raise("Missing jwt_secret in Rails credentials — run `rails credentials:edit`")
    end
  end
end
