module PublicIDable
  extend ActiveSupport::Concern

  included do
    before_validation :generate_public_id
    validates :public_id, presence: true, uniqueness: true
  end

  def to_param
    public_id
  end

  def self.from_param(param)
    find_by!(public_id: param)
  end

  private

  ALPHABET = "bcdfghjklmnpqrstvwxzBCDFGHJKLMNPQRSTVWXZ0123456789"

  def generate_public_id
    return if public_id
    self.public_id = begin
      Nanoid.generate(size: 8, alphabet: ALPHABET)
    end while public_id.nil? || self.class.exists?(public_id: public_id)
  end
end
