require "mastodon"
require "cgi"

class MastodonClient
  def initialize(base_url:, token:)
    @client = Mastodon::REST::Client.new(
      base_url:     base_url,
      bearer_token: token
    )
  end

  def mentions(since_id: nil)
    options = { limit: 20, exclude_types: [] }
    options[:since_id] = since_id if since_id && !since_id.to_s.empty?
    @client.notifications(options).select { |n| n.type == "mention" }
  rescue => e
    puts "[mentions 오류] #{e.message}"
    []
  end

  def reply(status_id, text)
    @client.create_status(
      text,
      in_reply_to_id: status_id,
      visibility:     "unlisted"
    )
  rescue => e
    puts "[reply 오류] #{e.message}"
  end

  def post_status(text, reply_to_id: nil, visibility: "unlisted")
    opts = { visibility: visibility }
    opts[:in_reply_to_id] = reply_to_id if reply_to_id
    @client.create_status(text, opts)
  rescue => e
    puts "[post_status 오류] #{e.message}"
  end

  def clean_content(notification)
    # mastodon-api gem은 Mastodon::Status 객체 반환
    html = notification.status.content
    text = html.gsub(/<br\s*\/?>/i, "\n")
               .gsub(/<\/p>/i, "\n")
               .gsub(/<[^>]+>/, "")
    CGI.unescapeHTML(text).strip
  end
end
