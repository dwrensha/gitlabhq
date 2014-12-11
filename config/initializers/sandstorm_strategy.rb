module Devise
  module Strategies
    class Sandstorm < Authenticatable
      def authenticate!
        Rails.logger.info 'Authenticating Sandstorm'
        userid = request.headers['HTTP_X_SANDSTORM_USER_ID'].encode(Encoding::UTF_8)
        username = URI.unescape(request.headers['HTTP_X_SANDSTORM_USERNAME']).force_encoding(Encoding::UTF_8)
        u = User.where(username: userid).first
        if !u
          opts = {}
          opts[:name] = username
          opts[:password] = "xyzzy123!xyzzy"
          opts[:username] = userid
          opts[:email] = userid + "@example.com"
          u = User.new(opts)
          u.generate_password
          u.generate_reset_token
          u.skip_confirmation!
          if u.save
            Rails.logger.info 'User was successfully created.'
          else
            Rails.logger.error 'User could not be created'
            Rails.logger.error u.errors
          end
        end

        permission_list = request.headers["HTTP_X_SANDSTORM_PERMISSIONS"].split(',')
        if (permission_list.include? 'admin') && !u.admin
          u.admin = true
          u.save
        end

        Rails.logger.info 'Done Authenticating Sandstorm'
        success!(u)
      end
      def valid?
        !!request.headers['HTTP_X_SANDSTORM_USER_ID']
      end
    end
  end
end
