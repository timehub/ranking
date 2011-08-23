require 'rubygems'
require 'nokogiri'
require 'open-uri'
require 'mysql2'
require 'active_record'
require 'active_support/all'


database_config = YAML.load_file(File.join(File.dirname(__FILE__), 'config/database.yml'))

puts "Connecting to database..."
ActiveRecord::Base.establish_connection(
  adapter: "mysql2", encoding: "utf8", database: "timehub_ranking", username: database_config["username"], password: database_config["password"]
)

class App < ActiveRecord::Base
  def self.setup
    ActiveRecord::Schema.define do
      create_table(:apps) do |t|
        t.string :title, :team, :url, :members, :team_url
        t.float :judges_integrity, :judges_interface, :judges_originality, :judges_utility
        t.float :public_integrity, :public_interface, :public_originality, :public_utility        
        t.integer :judges_score, :public_score
      end rescue nil
    end
  end

  def self.scrap(path)
    puts "scraping #{path}..."
    team_url = "http://rallyonrails.com#{path}"
    doc = Nokogiri::HTML(open(team_url).read.force_encoding('UTF-8'))

    url = doc.at("h3 a")["href"]
    votes = (doc / ".stars-1").map { |node| node.text.to_f }

    scores = doc.css("section hgroup h2").map(&:content).map do |line|
      match_data = line.match(/\((.*)(\ pts.\))/)
      match_data[1] if match_data
    end.compact
    
    judges_score = scores.first
    public_score = scores.second

    app = find_or_initialize_by_url(url)

    app.update_attributes :team               => (doc / "h1")[1].text,
                          :title              => doc.at("h3").text,
                          :url                => url,
                          :members            => doc.at("ul.members").children.map(&:text).map { |m| m.gsub(/\s+|\n/m, "") }.flatten.reject(&:blank?).join(" "),
                          
                          :judges_integrity   => votes[0],
                          :judges_interface   => votes[1],
                          :judges_originality => votes[2],
                          :judges_utility     => votes[3],
                          
                          :public_integrity   => votes[4],
                          :public_interface   => votes[5],
                          :public_originality => votes[6],
                          :public_utility     => votes[7],
                                                    
                          :team_url           => team_url,
                          :judges_score       => judges_score,
                          :public_score       => public_score
    
    puts app.attributes
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

  def judges_total
    (judges_integrity || 0) + (judges_interface || 0) + (judges_originality || 0) + (judges_utility || 0)
  end

  def public_total
    (public_integrity || 0) + (public_interface || 0) + (public_originality || 0) + (public_utility || 0)
  end

  def <=> (other)
    other.public_total <=> public_total
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
