require 'sinatra'
require 'sinatra-websocket'

set :server, 'thin'
set :sockets, []

get '/' do
  if !request.websocket?
    erb :index
  else
    request.websocket do |ws|
      ws.onopen do
        ws.send("curl http://#{request.host_with_port}/display -d msg=\"Hello World\"")
        settings.sockets << ws
      end
      ws.onmessage do |msg|
        EM.next_tick { settings.sockets.each{|s| s.send(msg) } }
      end
      ws.onclose do
        warn("websocket closed")
        settings.sockets.delete(ws)
      end
    end
  end
end

post '/display' do
  msg = params[:msg]
  EM.next_tick { settings.sockets.each{|s| s.send(msg) } }
end

__END__
@@ index
<html>
  <body style="margin:0; padding:0;">
     <div style="height:100vh; width:100vw; margin:0; padding:0;">
       <span id="msgs" style="font-size:900px"></span>
     </div>
  </body>

  <script type="text/javascript">
    window.onload = function(){
      (function(){
        var show = function(el){
          return function(msg){ el.innerHTML = msg; el.style.fontSize="900px"; adjust_heights(el) }
        }(document.getElementById('msgs'));
        
        var open_socket = function() {
          var ws       = new WebSocket('ws://' + window.location.host + window.location.pathname);
          ws.onopen    = function()  { show('websocket opened'); };
          ws.onclose   = function()  { show('websocket closed. Trying to open in 10 seconds'); setTimeout(open_socket, 10000); };
          ws.onmessage = function(m) { show(m.data); };
          return ws;
        };

        var ws = open_socket();

      })();
    }
    function adjust_heights(elem) {
      var parent = elem.parentElement;
      if (elem.offsetHeight>parent.offsetHeight || elem.offsetWidth>parent.offsetWidth) {
        elem.style.fontSize = parseInt(elem.style.fontSize) - 1 + 'px';
        adjust_heights(elem);
      }
    }
  </script>
</html>
