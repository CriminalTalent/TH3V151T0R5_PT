require "mastodon"
require "cgi"

class MastodonClient
  def initialize
    @client = Mastodon::REST::Client.new(
      base_url: ENV.fetch("MASTODON_BASE_URL"),
      bearer_token: ENV.fetch("MASTODON_ACCESS_TOKEN")
    )
  end

  def mentions(since_id: nil)
    options = { limit: 20 }
    options[:since_id] = since_id if since_id && !since_id.empty?

    @client.notifications("mention", options)
  end

  def reply(status_id, text)
    @client.create_status(
      text,
      in_reply_to_id: status_id,
      visibility: "unlisted"
    )
  end

  def clean_content(notification)
    html = notification.status.content
    text = html.gsub(/<br\s*\/?>/i, "\n")
               .gsub(/<\/p>/i, "\n")
               .gsub(/<[^>]+>/, "")
    CGI.unescapeHTML(text).strip
  end
end
