require 'rubygems'
require 'nokogiri'
require 'open-uri'
require 'mysql2'
require 'active_record'

ActiveRecord::Base.establish_connection(
  adapter: "mysql2", encoding: "utf8", database: "timehub_ranking", username: "root", password: ""
)

class App < ActiveRecord::Base
  def self.setup
    ActiveRecord::Schema.define do
      create_table(:apps) do |t|
        t.string :title, :team, :url, :members, :team_url
        t.float :integrity, :interface, :originality, :utility
        t.integer :score
      end rescue nil
    end
  end

  def self.scrap(path)
    puts "scraping #{path}..."
    team_url = "http://rallyonrails.com#{path}"
    doc = Nokogiri::HTML(open(team_url).read.force_encoding('UTF-8'))

    url = doc.at("h3 a")["href"]
    votes = (doc / ".stars-1").map { |node| node.text.to_f }

    score = doc.css("section hgroup h2").map(&:content).map do |line|
      match_data = line.match(/\((.*)(\ pts.\))/)
      match_data[1] if match_data
    end.compact.first.to_i

    app = find_or_initialize_by_url(url)

    app.update_attributes :team         => (doc / "h1")[1].text,
                          :title        => doc.at("h3").text,
                          :url          => url,
                          :members      => doc.at("ul.members").children.map(&:text).map { |m| m.gsub(/\s+|\n/m, "") }.flatten.reject(&:blank?).join(" "),
                          :integrity    => votes[0],
                          :interface    => votes[1],
                          :originality  => votes[2],
                          :utility      => votes[3],
                          :team_url     => team_url,
                          :score        => score
  rescue
    nil
  end

  def self.update_all
    doc = Nokogiri::HTML(open("http://rallyonrails.com/teams").read.force_encoding('UTF-8'))
    puts "  Loaded team index."
    (doc / "h2 a").map do |node|
      path = node["href"].to_s
      scrap(path) if path =~ /\/teams\/\d+/
    end.compact.sort
  end

  def total
    (integrity || 0) + (interface || 0) + (originality || 0) + (utility || 0)
  end

  def <=> (other)
    other.score <=> score
  end

  def to_s
    "#{title}: #{total} (#{url})"
  end

  def members
    read_attribute("members").to_s.split(" ").map do |attr|
      name = attr.to_s[/([^(]+)/] && $1
      $1.present? ? $1 : name
    end
  end
end

if ARGV.first == "update"
  puts "Updating..."
  App.setup
  App.update_all
  puts "Done. kthxbai."
else
  require 'sinatra'
  require 'haml'

  get("/") do
    @apps = App.all.sort
    haml :index
  end
end
