require 'shellwords'

module Sigh
  # Resigns an existing ipa file
  class Resign
    def run(options, args)
      # get the command line inputs and parse those into the vars we need...
      ipa, signing_identity, provisioning_profiles = get_inputs(options, args)

      # ... then invoke our programmatic interface with these vars
      resign(ipa, signing_identity, provisioning_profiles)
    end

    def self.resign(ipa, signing_identity, provisioning_profiles)
      self.new.resign(ipa, signing_identity, provisioning_profiles)
    end

    def resign(ipa, signing_identity, provisioning_profiles)
      resign_path = find_resign_path
      signing_identity = find_signing_identity(signing_identity)

      unless provisioning_profiles.kind_of?(Enumerable)
        provisioning_profiles = [provisioning_profiles]
      end

      # validate that we have valid values for all these params, we don't need to check signing_identity because `find_signing_identity` will only ever return a valid value
      validate_params(resign_path, ipa, provisioning_profiles)

      provisioning_options = provisioning_profiles.map { |fst, snd| "-p #{[fst, snd].compact.map(&:shellescape).join('=')}" }.join(' ')

      command = [
        resign_path.shellescape,
        ipa.shellescape,
        signing_identity.shellescape,
        provisioning_options, # we are aleady shellescaping this above, when we create the provisioning_options from the provisioning_profiles
        ipa.shellescape
      ].join(' ')

      puts command.magenta
      puts `#{command}`

      if $?.to_i == 0
        Helper.log.info "Successfully signed #{ipa}!".green
        true
      else
        Helper.log.fatal "Something went wrong while code signing #{ipa}".red
        false
      end
    end

    def get_inputs(options, args)
      ipa = args.first || find_ipa || ask('Path to ipa file: ')
      signing_identity = options.signing_identity || ask_for_signing_identity
      provisioning_profiles = options.provisioning_profile || find_provisioning_profile || ask('Path to provisioning file: ')

      return ipa, signing_identity, provisioning_profiles
    end

    def find_resign_path
      File.join(Helper.gem_path('sigh'), 'lib', 'assets', 'resign.sh')
    end

    def find_ipa
      Dir[File.join(Dir.pwd, '*.ipa')].sort { |a, b| File.mtime(a) <=> File.mtime(b) }.first
    end

    def find_provisioning_profile
      Dir[File.join(Dir.pwd, '*.mobileprovision')].sort { |a, b| File.mtime(a) <=> File.mtime(b) }.first
    end

    def find_signing_identity(signing_identity)
      until installed_identies.include?(signing_identity)
        Helper.log.error "Couldn't find signing identity '#{signing_identity}'."
        signing_identity = ask_for_signing_identity
      end

      signing_identity
    end

    def validate_params(resign_path, ipa, provisioning_profiles)
      validate_resign_path(resign_path)
      validate_ipa_file(ipa)
      provisioning_profiles.each { |fst, snd| validate_provisioning_file(snd || fst) }
    end

    def validate_resign_path(resign_path)
      raise 'Could not find resign.sh file. Please try re-installing the gem.'.red unless File.exist?(resign_path)
    end

    def validate_ipa_file(ipa)
      raise "ipa file could not be found or is not an ipa file (#{ipa})".red unless File.exist?(ipa) && ipa.end_with?('.ipa')
    end

    def validate_provisioning_file(provisioning_profile)
      raise "Provisioning profile file could not be found or is not a .mobileprovision file (#{provisioning_profile})".red unless File.exist?(provisioning_profile) && provisioning_profile.end_with?('.mobileprovision')
    end

    def print_available_identities
      Helper.log.info "Available identities: \n\t#{installed_identies.join("\n\t")}\n"
    end

    def ask_for_signing_identity
      print_available_identities
      ask('Signing Identity: ')
    end

    # Array of available signing identities
    def installed_identies
      available = `security find-identity -v -p codesigning`
      ids = []
      available.split("\n").each do |current|
        begin
          (ids << current.match(/.*\"(.*)\"/)[1])
        rescue
          nil
        end # the last line does not match
      end

      ids
    end
  end
end
