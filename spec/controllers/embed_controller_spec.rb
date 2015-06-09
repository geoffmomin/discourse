require 'spec_helper'

describe EmbedController do

  let(:host) { "eviltrout.com" }
  let(:embed_url) { "http://eviltrout.com/2013/02/10/why-discourse-uses-emberjs.html" }

  it "is 404 without an embed_url" do
    get :comments
    expect(response).not_to be_success
  end

  it "raises an error with a missing host" do
    SiteSetting.embeddable_hosts = nil
    get :comments, embed_url: embed_url
    expect(response).not_to be_success
  end

  context "with a host" do
    before do
      SiteSetting.embeddable_hosts = host
    end

    it "raises an error with no referer" do
      get :comments, embed_url: embed_url
      expect(response).not_to be_success
    end

    context "success" do
      before do
        controller.request.stubs(:referer).returns(embed_url)
      end

      after do
        expect(response).to be_success
        expect(response.headers['X-Frame-Options']).to eq("ALLOWALL")
      end

      it "tells the topic retriever to work when no previous embed is found" do
        TopicEmbed.expects(:topic_id_for_embed).returns(nil)
        retriever = mock
        TopicRetriever.expects(:new).returns(retriever)
        retriever.expects(:retrieve)
        get :comments, embed_url: embed_url
      end

      it "creates a topic view when a topic_id is found" do
        TopicEmbed.expects(:topic_id_for_embed).returns(123)
        TopicView.expects(:new).with(123, nil, {limit: 100, exclude_first: true, exclude_deleted_users: true})
        get :comments, embed_url: embed_url
      end
    end
  end

  context "with multiple hosts" do
    before do
      SiteSetting.embeddable_hosts = "#{host}\nhttp://discourse.org"
    end

    context "success" do
      it "works with the first host" do
        controller.request.stubs(:referer).returns("http://eviltrout.com/wat/1-2-3.html")
        get :comments, embed_url: embed_url
        expect(response).to be_success
      end

      it "works with the second host" do
        controller.request.stubs(:referer).returns("https://discourse.org/blog-entry-1")
        get :comments, embed_url: embed_url
        expect(response).to be_success
      end

      it "doesn't work with a made up host" do
        controller.request.stubs(:referer).returns("http://codinghorror.com/invalid-url")
        get :comments, embed_url: embed_url
        expect(response).to_not be_success
      end
    end
  end
end
