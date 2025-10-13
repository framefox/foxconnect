class JwtTokenService
  SECRET_KEY = ENV["JWT_SECRET_KEY"]

  def self.decode(token)
    JWT.decode(token, SECRET_KEY, true, algorithm: "HS256")[0]
  rescue JWT::DecodeError, JWT::ExpiredSignature => e
    Rails.logger.error("JWT decode error: #{e.message}")
    nil
  end
end
