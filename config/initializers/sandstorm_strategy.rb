module Devise
  module Strategies
    class Sandstorm < Authenticatable

      def authenticate!
        Rails.logger.info 'Authenticating Sandstorm'
        userid = request.headers['HTTP_X_SANDSTORM_USER_ID'].encode(Encoding::UTF_8)
        username = URI.unescape(request.headers['HTTP_X_SANDSTORM_USERNAME']).force_encoding(Encoding::UTF_8)
        email = userid + "@example.com" # this is what we actually use as a primary key.
        picture_url = request.headers["HTTP_X_SANDSTORM_USER_PICTURE"]

        u = User.where(email: email).first
        if !u
          handle = request.headers["HTTP_X_SANDSTORM_PREFERRED_HANDLE"] || userid || "no-name"
          if User.where(username: handle).first
            suffix = 0
            while User.where(username: (handle + "-" + suffix.to_s)).first
              suffix = suffix + 1
            end
            handle = (handle + "-" + suffix.to_s)
          end

          opts = {}
          opts[:name] = username
          opts[:password] = "xyzzy123!xyzzy"
          opts[:username] = handle
          opts[:email] = email
          opts[:hide_no_ssh_key] = true
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

        u.avatar = picture_url

        permission_list = request.headers["HTTP_X_SANDSTORM_PERMISSIONS"].split(',')
        if (permission_list.include? 'owner') && !u.admin
          u.admin = true
        end

        u.save

        p = Project.where(name: "repo").first
        role = Gitlab::Access::GUEST
        if permission_list.include? 'owner'
          role = Gitlab::Access::OWNER
        elsif permission_list.include? 'master'
          role = Gitlab::Access::MASTER
        elsif permission_list.include? 'developer'
          role = Gitlab::Access::DEVELOPER
        elsif permission_list.include? 'reporter'
          role = Gitlab::Access::REPORTER
        end
        if p
          p.team.add_user(u, role)
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
