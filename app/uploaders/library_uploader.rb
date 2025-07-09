require "shrine/storage/file_system"
require "shrine/storage/s3"
require "shrine/storage/tus"

class LibraryUploader < Shrine
  plugin :activerecord
  plugin :add_metadata
  plugin :refresh_metadata
  plugin :metadata_attributes, size: "size"
  plugin :restore_cached_data
  plugin :keep_files
  plugin :determine_mime_type
  plugin :rack_response
  plugin :dynamic_storage
  plugin :tus
  plugin :remote_url, max_size: SiteSettings.max_file_upload_size
  plugin :infer_extension

  self.storages = {
    cache: Shrine::Storage::FileSystem.new("tmp/shrine"),
    downloads: Shrine::Storage::FileSystem.new("tmp/downloads")
  }

  storage(/library_(\d+)/) do |m|
    Library.find(m[1]).storage # rubocop:disable Pundit/UsePolicyScope
  rescue ActiveRecord::RecordNotFound
    nil
  end

  class Attacher
    def store_key
      @record.model.library.storage_key
    end
  end

  def generate_location(io, record: nil, derivative: nil, metadata: {}, **)
    return super unless record&.valid?
    record.path_within_library
  end

  add_metadata :ctime do |io|
    Shrine.with_file(io) { |it| [it.mtime, it.ctime].compact.min }
  rescue NoMethodError
  end

  add_metadata :mtime do |io|
    Shrine.with_file(io) { |it| it.mtime }
  rescue NoMethodError
  end
end
