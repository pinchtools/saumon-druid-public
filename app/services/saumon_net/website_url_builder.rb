class SaumonNet::WebsiteUrlBuilder
  SOCIAL_PLATFORMS = {
    "facebook" => "https://facebook.com/",
    "twitter" => "https://twitter.com/",
    "instagram" => "https://instagram.com/",
    "linkedin" => "https://linkedin.com/"
  }.freeze

  def self.build(address_data)
    new(address_data).build
  end

  def initialize(address_data)
    @val_elec = address_data["valElec"]
    @type_libelle = address_data["typeLibelle"]
  end

  def build
    return @val_elec unless social_platform?

    "#{platform_base_url}#{@val_elec}"
  end

  private

  def social_platform?
    SOCIAL_PLATFORMS.key?(platform_name)
  end

  def platform_name
    @type_libelle&.downcase
  end

  def platform_base_url
    SOCIAL_PLATFORMS[platform_name]
  end
end
