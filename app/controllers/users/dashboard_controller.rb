class Users::DashboardController < ApplicationController
  def index
    #get last message that is less than one year old for each unique (sender and category)
    sorted_table_sql = "SELECT sender_email, category, max(received_at) AS received_at FROM messages WHERE received_at >= '#{DateTime.now - 1.year}' GROUP BY sender_email, category"
    required_values_sql = "SELECT messages.id, messages.category, messages.sender_email, messages.subject, messages.received_at, messages.extracted_datetime FROM messages INNER JOIN (#{sorted_table_sql}) AS sorted_table ON messages.sender_email = sorted_table.sender_email AND messages.category = sorted_table.category AND messages.received_at = sorted_table.received_at ORDER BY messages.received_at DESC"

    @messages = ActiveRecord::Base.connection.execute(required_values_sql)
  end
end
