require 'yaml'
require 'fileutils'

class App2Container
  def self.convert(app_name, tag, options={})
    App2Container.new(app_name, tag, options)
  end

  def initialize(app_name, tag, options={})
    @app_name = app_name
    @tag = tag || "latest"
    @buildpack_url = options[:buildpack_url]
    @includes = options[:includes]
    @file = options[:file]
    @from = options[:from]

    create_dockerfile
    build_container

    if options[:port]
      run_container(options[:port])
    else
      explain_container(8080)
    end
    exit 0
  end

  def create_dockerfile
    File.open("Dockerfile" , "w") do |file|
      file << "FROM #{@from || "progrium/buildstep"}\n"
    end

    if @buildpack_url
      File.open("Dockerfile" , "a") do |file|
        file << <<-eof
RUN git clone --depth 1 #{@buildpack_url} /build/buildpacks/#{@buildpack_url.split("/").last.sub(".git","")}
RUN echo #{@buildpack_url} >> /build/buildpacks.txt
eof
      end
    end

    if @includes
      File.open("Dockerfile" , "a") do |file|
        file << "RUN #{@includes}\n"
      end
    end

    if @file
      File.open("Dockerfile" , "a") do |file|
        file << IO.read(@file)
      end
    end

    File.open("Dockerfile" , "a") do |file|
      file << <<-eof
ADD . /app
RUN /build/builder
CMD /start web
eof
    end
  end

  def build_container
    pid = fork { exec "docker build -t #{@app_name}:#{@tag} ." }
    Process.waitpid(pid)
  end

  def explain_container(port)
    run = "docker run -d -p #{port} -e \"PORT=#{port}\" #{@app_name}:#{@tag}"
    puts "\nTo run your app, try something like this:\n\n\t#{run}\n\n"
  end

  def run_container(port)
    run = "\ndocker run -d -p #{port} -e \"PORT=#{port}\" #{@app_name}:#{@tag}"
    puts "#{run}"
    exec run
  end
end
