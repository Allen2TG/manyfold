require "rails_helper"

RSpec.describe User do
  it_behaves_like "Follower"
  it_behaves_like "Caber::Subject"

  it "requires a username" do
    expect(build(:user, username: nil)).not_to be_valid
  end

  it "allows single-character usernames" do
    expect(build(:user, username: "a")).to be_valid
  end

  it "allows two-character usernames" do
    expect(build(:user, username: "ab")).to be_valid
  end

  it "allow three-character usernames" do
    expect(build(:user, username: "abc")).to be_valid
  end

  it "allows numbers in usernames" do
    expect(build(:user, username: "3jane")).to be_valid
  end

  it "allows non-ASCII usernames" do
    expect(build(:user, username: "إعلانات")).to be_valid
  end

  it "doesn't allows punctuation in usernames" do
    expect(build(:user, username: "user-name")).not_to be_valid
  end

  it "doesn't allow usernames that differ by case" do
    create(:user, username: "userName")
    expect(build(:user, username: "USERNAME")).not_to be_valid
  end

  it "gets member role by default" do
    u = create(:user)
    expect(u).to have_role(:member)
  end

  it "gets contributor and member roles if contributor is set as default" do # rubocop:disable RSpec/MultipleExpectations
    allow(SiteSettings).to receive(:default_signup_role).and_return("contributor")
    u = create(:user)
    expect(u).to have_role(:member)
    expect(u).to have_role(:contributor)
  end

  it "enables quotas" do
    SiteSettings.enable_user_quota = true
    SiteSettings.default_user_quota = 100
    expect(build(:user).has_quota?).to be_truthy # rubocop:disable RSpec/PredicateMatcher
  end

  it "assigned site quota not explicitly defined" do
    expect(build(:user).quota).to eq SiteSettings.default_user_quota
  end

  it "uses site default quota" do
    SiteSettings.default_user_quota = 100
    user = create(:user, quota: 42, quota_use_site_default: true)
    expect(user.quota).to eq SiteSettings.default_user_quota
  end

  it "considers zero quota value as unlimited" do
    user = create(:user, quota: 0, quota_use_site_default: false)
    expect(user.has_quota?).to be_falsey # rubocop:disable RSpec/PredicateMatcher
  end

  context "when autocreating creator" do
    it "creates creator successfully if data is valid" do
      user = create(:user, creators_attributes: [{slug: "creator", name: "Creator"}])
      expect(user.creators.first.name).to eq "Creator"
    end

    it "validates creator data properly" do
      user = build(:user, creators_attributes: [{slug: "invalid+slug", name: ""}])
      expect(user).not_to be_valid
    end

    it "logs errors with creator data properly" do # rubocop:disable RSpec/MultipleExpectations
      user = build(:user, creators_attributes: [{slug: "invalid+slug", name: ""}])
      user.validate
      expect(user.errors.where("creators.name").first.type).to eq :blank
      expect(user.errors.where("creators.slug").first.type).to eq :invalid
    end
  end

  context "with owner permissions on a creator" do
    let!(:user) { create(:user) }
    let!(:creator) { create(:creator) }

    it "accesses owned creators through association" do
      creator.grant_permission_to("own", user)
      expect(user.reload.creators).to include creator
    end

    it "can't access non-owned creators through association" do
      creator.grant_permission_to("own", create(:moderator))
      expect(user.creators).to be_empty
    end

    it "doesn't access viewable creators through association" do
      creator.grant_permission_to("view", user)
      expect(user.reload.creators).to be_empty
    end
  end

  context "with omniauth" do
    let(:auth_data) do
      OpenStruct.new({
        provider: "openid_connect",
        uid: "auth|123456789",
        info: OpenStruct.new({
          email: "test@example.com",
          preferred_username: "username",
          nickname: "nick"
        })
      })
    end

    it "can create a valid user from auth data" do
      expect(described_class.from_omniauth(auth_data)).to be_valid
    end

    it "stores auth provider" do
      user = described_class.from_omniauth(auth_data)
      expect(user.auth_provider).to eq "openid_connect"
    end

    it "stores auth uid" do
      user = described_class.from_omniauth(auth_data)
      expect(user.auth_uid).to eq "auth|123456789"
    end

    it "stores email" do
      user = described_class.from_omniauth(auth_data)
      expect(user.email).to eq "test@example.com"
    end

    it "stores username" do
      user = described_class.from_omniauth(auth_data)
      expect(user.username).to eq "username"
    end

    it "stores nickname as username if preferred username not available" do
      auth_data.info.preferred_username = nil
      user = described_class.from_omniauth(auth_data)
      expect(user.username).to eq "nick"
    end

    it "stores email username as username if preferred username and nickname not available" do
      auth_data.info.preferred_username = nil
      auth_data.info.nickname = nil
      user = described_class.from_omniauth(auth_data)
      expect(user.username).to eq "test"
    end

    it "matches an existing user with identical auth details" do
      user = create(:user, auth_provider: "openid_connect", auth_uid: "auth|123456789")
      expect(described_class.from_omniauth(auth_data)).to eq user
    end

    it "matches an existing user with matching email" do
      user = create(:user, email: "test@example.com")
      expect(described_class.from_omniauth(auth_data)).to eq user
    end

    it "deconflicts a user with matching username by using one of the other options" do
      create(:user, username: "username")
      new_user = described_class.from_omniauth(auth_data)
      expect(new_user.username).to eq "nick"
    end
  end
end
