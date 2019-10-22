class LocalSound < Sound
  if CONFIG.usingS3
    has_attached_file :file,
      preserve_files: true,
      storage: :s3,
      s3_credentials: "#{Rails.root}/config/s3.yml",
      s3_protocol: CONFIG.s3_protocol || "https",
      s3_host_alias: CONFIG.s3_host || CONFIG.s3_bucket,
      s3_region: CONFIG.s3_region,
      bucket: CONFIG.s3_bucket,
      path: "sounds/:id.:content_type_extension",
      url: ":s3_alias_url"
    invalidate_cloudfront_caches :file, "sounds/:id.*"
  else
    has_attached_file :file,
      path: ":rails_root/public/attachments/:class/:attachment/:id.:content_type_extension",
      url: "/attachments/:class/:attachment/:id.:content_type_extension"
  end

  validates_attachment_content_type :file,
    content_type: [/wav/i, /mpeg/i, /mp3/i, /m4a/i, "audio/mp4", /aac/, /3gpp/i, /audio\/AMR/i],
    message: "must be a WAV, MP3, M4A, or AMR"

  def to_observation
    o = Observation.new
    o.sounds.build( self.attributes )
    o
  end

  def file=( data )
    unless data.respond_to?(:path) && data.respond_to?(:original_filename)
      return self.file.assign( data )
    end
    content_type = InatContentTypeDetector.new( data.path ).detect
    # For whatever reason, the file command tends to recognize mp3 files as
    # audio/mpeg, mp4 files as video/mp4, and m4a files as audio/x-m4a. The
    # intent here is to not convert wav and mp3 files
    if [
      "audio/wav",
      "audio/wave",
      "audio/x-wav",
      "audio/mpeg"
    ].include?( content_type )
      self.file.assign( data )
    else
      file_format = File.extname( data.path )
      file_basename = File.basename( data.original_filename, file_format )
      dest_path = dst_path = File.join( Dir.tmpdir, "#{file_basename}.m4a" )
      # begin
      # -i specifies the input
      # -vn ensures the output has no video
      # -y overwrites the output path regardless of what's there
      # -strict -2 allows use of an experimental AAC codec on linux
      line = Terrapin::CommandLine.new(
        "ffmpeg",
        "-i :source -vn -y -strict -2 :dest"
      )
      line.run(
        source: data.path,
        dest: dest_path
      )
      File.open( dest_path, "rb" ) do |f|
        self.file.assign( f )
      end
    end
  end
end
