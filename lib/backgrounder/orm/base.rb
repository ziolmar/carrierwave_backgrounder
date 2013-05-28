# encoding: utf-8
require 'backgrounder/workers'

module CarrierWave
  module Backgrounder
    module ORM

      ##
      # Base class for all things orm
      module Base

        ##
        # User#process_in_background will process and create versions in a background process.
        #
        # class User < ActiveRecord::Base
        #   mount_uploader :avatar, AvatarUploader
        #   process_in_background :avatar
        # end
        #
        # The above adds a User#process_upload method which can be used at times when you want to bypass
        # background storage and processing.
        #
        #   @user.process_avatar = true
        #   @user.save
        #
        # You can also pass in your own workers using the second argument in case you need other things done
        # during processing.
        #
        #   class User < ActiveRecord::Base
        #     mount_uploader :avatar, AvatarUploader
        #     process_in_background :avatar, CustomWorker
        #   end
        #
        # In addition you can also add a column to the database appended by _processing with a type of boolean
        # which can be used to check if processing is complete.
        #
        #   def self.up
        #     add_column :users, :avatar_processing, :boolean
        #   end
        #
        def process_in_background(column, worker=::CarrierWave::Workers::ProcessAsset, &block)
          attr_accessor :"process_#{column}_upload"

          mod = Module.new do
            define_method :"#{column}_updated?" do
              true
            end

            define_method :"set_#{column}_processing" do
              self.send(:"#{column}_processing=", true) if respond_to?(:"#{column}_processing")
            end

            define_method :"enqueue_#{column}_background_job?" do
              !self.send(:"remove_#{column}?") && !self.send(:"process_#{column}_upload") && self.send(:"#{column}_updated?")
            end

            define_method :"enqueue_#{column}_background_job" do
              CarrierWave::Backgrounder.enqueue_for_backend(worker, self.class.name, id.to_s, self.send(:"#{column}.mounted_as"))
            end

            block.call(mod) if block_given?
          end
          include mod
        end

        ##
        # #store_in_background  will process, version and store uploads in a background process.
        #
        # class User < ActiveRecord::Base
        #   mount_uploader :avatar, AvatarUploader
        #   store_in_background :avatar
        # end
        #
        # The above adds a User#process_<column>_upload method which can be used at times when you want to bypass
        # background storage and processing.
        #
        #   @user.process_avatar_upload = true
        #   @user.save
        #
        # You can also pass in your own workers using the second argument in case you need other things done
        # during processing.
        #
        #   class User < ActiveRecord::Base
        #     mount_uploader :avatar, AvatarUploader
        #     store_in_background :avatar, CustomWorker
        #   end
        #
        def store_in_background(column, worker=::CarrierWave::Workers::StoreAsset)
          process_in_background(column, worker) do |mod|
            define_method :"write_#{column}_identifier" do
              super and return if self.send(:"process_#{column}_upload")
              self.send(:"#{column}_tmp=", _mounter(:"#{column}").cache_name) if _mounter(:"#{column}").cache_name
            end

            define_method :"store_#{column}!" do
              super if self.send(:"process_#{column}_upload")
            end
          end
        end

        private

      end # Base

    end #ORM
  end #Backgrounder
end #CarrierWave
