class Users::DashboardController < ApplicationController
  def index
    #Get last message for each unique (sender and category) combination (must have been received less than one year ago)
    ##Use ActiveRecord DSL where possible

    #Save sql string for getting the last message received for each sender_email, category combination
    ##sql string generated: "SELECT sender_email, category, max(received_at) AS received_at FROM messages WHERE received_at >= '#{1.year.ago}' GROUP BY sender_email, category"
    grouped_messages_sql_str = Message.select("sender_email, category, max(received_at) AS received_at").where(received_at: 1.year.ago..Time.now).group(:sender_email, :category).to_sql

    #Get all message columns for generated earlier sorted and grouped message rows by joining initial results from grouped_messages_sql_str on sender email, category and received at datetime
    ##generate join parameters str
    join_parameters = ["sender_email", "category", "received_at"]
    join_grouped_messages_on_messages_sql_str = ""
    ##generated join_grouped_messages_on_messages_sql_str: "messages.sender_email = grouped_messages.sender_email AND messages.category = grouped_messages.category AND messages.received_at = grouped_messages.received_at"
    join_conditions = join_parameters.each_with_index do |join_parameter, index|
      join_grouped_messages_on_messages_sql_str += "messages.#{join_parameter} = grouped_messages.#{join_parameter}"
      join_grouped_messages_on_messages_sql_str += " AND " unless index == (join_parameters.count - 1)
    end


    #Complete SQL query: SELECT  "messages".* FROM "messages" INNER JOIN (SELECT sender_email, category, max(received_at) AS received_at FROM "messages" WHERE ("messages"."received_at" BETWEEN '#{1.year.ago}' AND '#{Time.now}') GROUP BY "messages"."sender_email", "messages"."category") AS grouped_messages ON messages.sender_email = grouped_messages.sender_email AND messages.category = grouped_messages.category AND messages.received_at = grouped_messages.received_at ORDER BY "messages"."received_at"
    @messages = Message.joins("INNER JOIN (#{grouped_messages_sql_str}) AS grouped_messages ON #{join_grouped_messages_on_messages_sql_str}").order(:received_at).reverse_order
  end
end
