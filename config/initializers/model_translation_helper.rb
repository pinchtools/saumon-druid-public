module ModelTranslationHelper
  extend ActiveSupport::Concern

  class_methods do
    # Usage:
    #   humanize("capacities.depute_non_inscrit.label")
    #   humanize(:capacities, :depute_non_inscrit, :label)
    #
    def humanize(*keys)
      flat_key =
        if keys.length == 1 && keys.first.is_a?(String)
          keys.first
        else
          keys.flatten.join(".")
        end

      i18n_key = [
        "activerecord.attributes",
        model_name.i18n_key,
        flat_key
      ].join(".")

      I18n.t(i18n_key, default: i18n_fallback(flat_key))
    end

    private

    # Fallback used when the translation is missing:
    # humanize like human_attribute_name does
    def i18n_fallback(key)
      key.to_s.split(".").last.humanize
    end
  end
end

ActiveRecord::Base.include(ModelTranslationHelper)
