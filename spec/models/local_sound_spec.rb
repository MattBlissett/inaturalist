require File.dirname(__FILE__) + '/../spec_helper.rb'

describe LocalSound, "creation" do
  it "should convert an AMR file to M4A" do
    ls = LocalSound.create!(
      user: User.make!,
      file: File.open( File.join( Rails.root, "spec/fixtures/files/pika.amr" ) )
    )
    expect( ls.file.content_type ).to eq "audio/mp4"
  end

  it "should not convert an MP3 to an MP4" do
    ls = LocalSound.create!(
      user: User.make!,
      file: File.open( File.join( Rails.root, "spec/fixtures/files/pika.mp3" ) )
    )
    expect( ls.file.content_type ).to eq "audio/mp3"
  end
end
