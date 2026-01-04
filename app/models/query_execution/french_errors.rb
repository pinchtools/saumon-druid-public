# frozen_string_literal: true

module QueryExecution
  module FrenchErrors
    MESSAGES = {
      model_not_found: "Le type de données demandé n'est pas disponible.",
      invalid_action: "L'action demandée n'est pas supportée pour ce type de données.",
      no_results: "Aucun résultat trouvé pour votre recherche.",
      dependency_failed: "Une étape préalable a échoué, impossible de continuer.",
      timeout: "La recherche a pris trop de temps. Veuillez réessayer.",
      invalid_date: "Le format de date fourni n'est pas valide.",
      invalid_parameters: "Les paramètres fournis ne sont pas valides.",
      ambiguous_query: "Votre requête est ambiguë. Pourriez-vous préciser : %{suggestions}?",
      database_error: "Une erreur est survenue lors de l'accès aux données.",
      unknown_error: "Une erreur inattendue s'est produite."
    }.freeze

    class << self
      def for(error_type, **params)
        message = MESSAGES.fetch(error_type, MESSAGES[:unknown_error])
        return message if params.empty?

        message % params
      rescue KeyError => e
        Rails.logger.warn("Missing interpolation key in FrenchErrors: #{e.message}")
        MESSAGES[:unknown_error]
      end

      def available_error_types
        MESSAGES.keys
      end
    end
  end
end
