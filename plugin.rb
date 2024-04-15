# name: critique_ratio
# about: Displays the critique ratio next to the user's username
# version: 1.0
# authors: Your Name

enabled_site_setting :critique_ratio_enabled

after_initialize do
  module ::CritiqueRatio
    class Engine < ::Rails::Engine
      engine_name "critique_ratio"
      isolate_namespace CritiqueRatio
    end
  end

  require_dependency "application_controller"
  class CritiqueRatio::CritiqueRatioController < ::ApplicationController
    def index
      query = "SELECT
                 u.username,
                 COALESCE(t.created_topics, 0) AS created_topics,
                 COALESCE(p.replies_to_others, 0) AS replies_to_others,
                 COALESCE(ROUND(p.replies_to_others::numeric / NULLIF(t.created_topics, 0), 2), 0) AS ratio
               FROM
                 users u
                 LEFT JOIN (
                   SELECT
                     user_id,
                     COUNT(*) AS created_topics
                   FROM
                     topics
                   WHERE
                     created_at >= CURRENT_DATE - INTERVAL '6 months'
                     AND category_id IN (
                       SELECT id FROM categories WHERE parent_category_id = 87 OR id = 87
                     )
                   GROUP BY
                     user_id
                 ) t ON t.user_id = u.id
                 LEFT JOIN (
                   SELECT
                     p.user_id,
                     COUNT(*) AS replies_to_others
                   FROM
                     posts p
                     JOIN topics t ON p.topic_id = t.id
                   WHERE
                     p.post_number > 1
                     AND p.user_id != t.user_id
                     AND p.created_at >= CURRENT_DATE - INTERVAL '6 months'
                     AND t.category_id IN (
                       SELECT id FROM categories WHERE parent_category_id = 87 OR id = 87
                     )
                     AND LENGTH(p.raw) >= 100
                   GROUP BY
                     p.user_id
                 ) p ON p.user_id = u.id
               WHERE
                 t.created_topics > 0 OR p.replies_to_others > 0
               ORDER BY
                 ratio DESC"
      @results = DiscourseDataExplorer.run_query(query)
    end
  end

  Discourse::Application.routes.append do
    mount ::CritiqueRatio::Engine, at: '/critique-ratio'
  end

  add_to_serializer(:user, :critique_ratio) do
    result = CritiqueRatio::CritiqueRatioController.new.index
    ratio = result.find { |r| r['username'] == object.username }&.[]('ratio') || 0
    "Critique Ratio: #{ratio}"
  end

  register_asset "stylesheets/critique-ratio.scss"
  register_asset "javascripts/discourse/initializers/critique-ratio.js.es6", :client
end
