class Users::DashboardController < ApplicationController
  def index
    # Get last msg for each uniq (sender & category) combo for user
    #  (must have been received less than one year ago)
    # Use ActiveRecord DSL where possible

    list_of_folders_ids_for_user = current_user.folders.pluck(:id)

    # SQL string to get last msg received for each sender_email, category combo
    #  SELECT sender_email, category, max(received_at) AS received_at
    #  FROM messages WHERE received_at >= '#{1.year.ago}'
    #  AND folder_id IN (#{list_of_folders_ids_for_user})
    #  GROUP BY sender_email, category"
    grouped_messages_sql_str =
      Message.select("
               sender_email, category, max(received_at) AS received_at
             ")
             .where(
               received_at: (1.year.ago..Time.now),
               folder_id: list_of_folders_ids_for_user
             )
             .group(:sender_email, :category)
             .to_sql

    # SQL string to join above table on entire message table to get all columns
    join_grouped_messages_on_messages_sql_str = "
        messages.sender_email = grouped_messages.sender_email AND
        messages.category = grouped_messages.category AND
        messages.received_at = grouped_messages.received_at
      "

    # Complete SQL query:
    #  SELECT  "messages".* FROM "messages"
    #  INNER JOIN (
    #   SELECT sender_email, category, max(received_at) AS received_at
    #   FROM "messages"
    #   WHERE (
    #           "messages"."received_at"
    #            BETWEEN '#{1.year.ago}'
    #            AND '#{Time.now}'
    #         )
    #   GROUP BY "messages"."sender_email", "messages"."category"
    #  ) AS grouped_messages
    #  ON
    #   messages.sender_email = grouped_messages.sender_email AND
    #   messages.category = grouped_messages.category AND
    #   messages.received_at = grouped_messages.received_at
    #  ORDER BY "messages"."received_at"
    @messages =
      Message.joins("
               INNER JOIN (#{grouped_messages_sql_str}) AS grouped_messages
               ON #{join_grouped_messages_on_messages_sql_str}
             ")
             .order(:received_at)
             .reverse_order
  end
end
