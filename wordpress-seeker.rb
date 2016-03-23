require 'net/imap'
require 'mail'
require 'nokogiri'
require 'slack-notifier'

# Find Beloved Wordpress Work 
class WPSeeker

	def initialize()
		slack_webhook_url = 'SLACK_HOOK_URL'
		@slack = Slack::Notifier.new slack_webhook_url, channel: '#craigslist', username: 'wp-seeker'

		workLoop()
	end

	# run once a minute
	def workLoop()
		while true
			workTick()
			sleep(60)
		end
	end

	def workTick

		# login to the IMAP account where the "Saved Search" alerts are going to
		begin
			puts "login"
			imap = Net::IMAP.new('mail.yourserver.com', ssl:true) 
			imap.login('your-imap-login', 'your-imap-password')
			imap.select('INBOX')
			imap.expunge
		rescue => e
			puts "#{e}"
			return true
		end

		# find alerts
		imap.search(["FROM", "alerts@craigslist.org"]).each do |message_id|

			msg = imap.fetch(message_id,'RFC822')[0].attr['RFC822']
			mail = Mail.read_from_string msg
			body = mail.parts[1].body.decoded	# grab the HTML part from the multipart message

			# easy-peasy
			doc = Nokogiri::HTML(body)
			doc.css('ul li a').each do |a|
				puts "#{a.text()} #{a.attr('href')}"
				@slack.ping "#{a.text()}\n#{a.attr('href')}\n\n"
			end

			# delete-a-roo
			imap.store(message_id, "+FLAGS", [:Deleted])

		end

	end
end

WPSeeker.new