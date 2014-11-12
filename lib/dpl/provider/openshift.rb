module DPL
  class Provider
    class Openshift < Provider
      # rhc 1.25.3 and later are required for httpclient 2.4.0 and up
      # See https://github.com/openshift/rhc/pull/600
      requires 'httpclient', version: '~> 2.4.0'
      requires 'rhc', version: '~> 1.25.3'
      #requires 'archive-tar', version: '~> 0.9.0'

      def initialize(context, options)
        super
        @deployment_branch = options[:deployment_branch]
      end

      def api
        @api ||= ::RHC::Rest::Client.new(:user => option(:user), :password => option(:password), :server => 'openshift.redhat.com')
      end

      def user
        @user ||= api.user.login
      end

      def app
        @app ||= api.find_application(option(:domain), option(:app))
      end

      def check_auth
        log "authenticated as %s" % user
      end

      def check_app
        log "found app #{app.name}"
      end

      def setup_key(file, type = nil)
        specified_type, content, comment = File.read(file).split
        api.add_key(option(:key_name), content, type || specified_type)
      end

      def remove_key
        api.delete_key(option(:key_name))
      end

      def push_app
        if app.deployment_type == "binary"
          log "Application deployment type is set to 'binary'; deploying build results."
          binary_deploy
        elsif @deployment_branch
          log "deployment_branch detected: #{@deployment_branch}"
          app.deployment_branch = @deployment_branch
          context.shell "git push #{app.git_url} -f #{app.deployment_branch}"
        else
          context.shell "git push #{app.git_url} -f"
          puts "Pushing app."
        end
      end

      def binary_deploy
        compile_tarball
      end

      ##
      # build_dependencies/
      # dependencies/
      #    jbosseap/ [need to trsanlate this one]
      #        deployments/
      #            [binaries]
      # repo/
      #    .openshift/
      def compile_tarball
        branch = ENV.fetch('TRAVIS_BRANCH', 'application')
        build_id = ENV.fetch('TRAVIS_JOB_ID', rand(9999).to_s)
        location = ENV.fetch('TRAVIS_BUILD_DIR' + '/../', '../')
        folder_name = branch + "_" + build_id
        Dir.mkdir(location + folder_name)
      end

      def restart
        app.restart
      end

    end
  end
end
