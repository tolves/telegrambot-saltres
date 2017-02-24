
#创建活动，由于需要三次输入，所以分三步，活动名，活动详情，活动密级。并且自动将当前用户设置为 此活动管理员
def create_activity message,bot
	agent_auth = @query_agent_admin_statement.execute(message.from.id)
	bot.logger.info(message.from.id)
	if agent_auth.size == 0
		bot.api.edit_message_text chat_id: message.from.id, message_id:message.message.message_id, text:'少年郎你没有创建权限啦'
		return false
	end
	bot.api.send_message chat_id: message.from.id, text: '请输入要创建的活动名称：', reply_markup:@force_reply
end


def create_activity_name message,bot
	activity_name = message.text.strip.encode(:xml => :text)
	@activity = [activity_name]
	bot.api.send_message chat_id: message.from.id, text: '成功新建活动，请继续输入活动详情：', reply_markup:@force_reply
end


def create_activity_detail message,bot
	if @activity.nil?
		bot.api.send_message chat_id: message.from.id, text: '发生了豆腐丝不想看见的事件，点击 /go 返回，找豆腐丝豆腐丝也不修'
		return false
	end
	activity_detail = message.text.strip.encode(:xml => :text)
	@activity << activity_detail

	security_kb = security_level_keyboard
	security_makeup =  Telegram::Bot::Types::InlineKeyboardMarkup.new(inline_keyboard: security_kb)

	bot.api.send_message chat_id: message.from.id, text: '成功添加活动详情，请选择活动密级：', reply_markup: security_makeup
end


def create_activity_security_level message,bot
	if @activity.nil?
		bot.api.send_message chat_id: message.from.id, text: '发生了豆腐丝不想看见的事件，点击 /go 返回，找豆腐丝豆腐丝也不修'
		return false
	end
	security_level = message.data.split('_',3)[2]
	@activity << security_level

	activity_statement = @client.prepare("INSERT INTO activity (name,detail,security,created_on,updated_on,status) VALUES (?,?,?,\"#{Time.now.strftime("%Y-%m-%d %H:%M:%S")}\",\"#{Time.now.strftime("%Y-%m-%d %H:%M:%S")}\",\"1\")")
	activity_user_statement = @client.prepare("INSERT INTO activity_users (activity_id,telegram_id,duty) VALUES (?,?,\"1\")")

	begin
		activity_statement.execute(@activity[0],@activity[1],@activity[2])
		l_id = @client.query("SELECT LAST_INSERT_ID()").first
		activity_user_statement.execute(l_id['LAST_INSERT_ID()'],message.from.id)
		@update_agent_updatedate_by_telegram_id.execute(message.from.id)
		@activity = nil
	rescue
		raise_errormessage message,bot
		retry
	end

	bot.api.edit_message_text chat_id: message.from.id, message_id:message.message.message_id, text: "成功设置活动密级，点击 /go 返回大厅"
end

#查看当前所有活跃的活动
def view_availalbe_activity message,bot
	availalbe_activities = @client.query("SELECT * FROM activity AS ay LEFT JOIN security AS secu ON ay.security=secu.id where status=1")
	acty_kb_a = Array.new
	availalbe_activities.each do |activity|
		acty_kb_a << Telegram::Bot::Types::InlineKeyboardButton.new(text: activity['name'], callback_data: "valid_activity_#{activity['id']}")
	end
	acty_kb = Array.new
	acty_kb_a.each_slice(2){|kb| acty_kb<<kb}
	acty_makeup = Telegram::Bot::Types::InlineKeyboardMarkup.new(inline_keyboard: acty_kb)
	bot.api.edit_message_text chat_id: message.from.id, message_id:message.message.message_id, text:'活跃活动列表：', reply_markup: acty_makeup
end


def view_actitivy_created_byme message,bot
	activities = @query_activity_created_byme_by_telegram_id.execute message.from.id
	acty_creabyme_kb = Array.new

	activities.each do |activity|
		# bot.logger.info()
		status = activity['status'] == 0?'已存档':'活动'
		acty_creabyme_kb << Telegram::Bot::Types::InlineKeyboardButton.new(text: "#{activity['name']} - #{status}", callback_data: "valid_activities_created_byme_#{activity['id']}")
	end
	acty_creabyme_kb << Telegram::Bot::Types::InlineKeyboardButton.new(text: "返回大厅", callback_data: "back_overview")
	acty_creabyme_makeup = Telegram::Bot::Types::InlineKeyboardMarkup.new(inline_keyboard: acty_creabyme_kb)
	bot.api.edit_message_text chat_id: message.from.id, message_id:message.message.message_id, text:'我创建的活动：', reply_markup: acty_creabyme_makeup
end