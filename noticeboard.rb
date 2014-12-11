require 'sinatra'
require 'sinatra-websocket'

set :server, 'thin'
set :sockets, []

get '/' do
  $last_msg ||= "curl https://#{request.host_with_port}/display -d msg=\"Hello World\""

  if !request.websocket?
    erb :index
  else
    request.websocket do |ws|
      ws.onopen do
        ws.send($last_msg)
        settings.sockets << ws
      end
      ws.onmessage do |msg|
        EM.next_tick { settings.sockets.each{|s| s.send(msg) } } unless msg == 'ping'
      end
      ws.onclose do
        warn("websocket closed")
        settings.sockets.delete(ws)
      end
    end
  end
end

post '/display' do
  $last_msg = params[:msg]
  $font = params[:font]
  EM.next_tick { settings.sockets.each{|s| s.send("font=#{$font}") if $font; s.send($last_msg) } }
end

__END__
@@ index
<html>
  <head>
    <link href='http://fonts.googleapis.com/css?family=Roboto:400,700' rel='stylesheet' type='text/css'>
  </head>
  <body style="margin:0; padding:0;">
     <div style="height:100vh; width:100vw; margin:0; padding:0;">
       <span id="msgs" style="font-family: 'Roboto'; font-size:900px; text-align:center; display:block"></span>
       <div id="instructions" style="position:absolute; bottom:0; right:0">curl http://<%=request.host_with_port%>/display -d msg="Hello World" -d font="Fredoka One"</div>
     </div>
  </body>

  <script>
    WebFontConfig = {
    google: {
      families: ['Roboto']
      }
    };
  </script>
  <script src="//ajax.googleapis.com/ajax/libs/webfont/1.5.6/webfont.js"></script>
  <script type="text/javascript">
    window.onload = function(){
      (function(){
        var show = function(el){
          return function(msg){ 
            if(font_msg = msg.match(/^font=(.*)/)) {
              load_font(font_msg[1]);
            } else {
              el.innerHTML = msg; 
              el.style.fontSize="900px"; 
              adjust_heights(el) 
            }
          }
        }(document.getElementById('msgs'));
        
        var open_socket = function() {
          # This needs to be ws:// for localhost development
          var ws       = new WebSocket('wss://' + window.location.host + window.location.pathname);
          ws.onopen    = function()  { show('websocket opened'); };
          ws.onclose   = function()  { show('websocket closed. Trying to open in 10 seconds'); setTimeout(open_socket, 10000); };
          ws.onmessage = function(m) { show(m.data); };
          return ws;
        };

        var send_ping = function(ws) {
          ws.send('ping');
        };

        var ws = open_socket();

        setInterval(function() {send_ping(ws)}, 50000);

      })();
    };

    function adjust_heights(elem) {
      elem.style.display = "";
      var parent = elem.parentElement;
      if (elem.offsetHeight>parent.offsetHeight || elem.offsetWidth>parent.offsetWidth) {
        elem.style.fontSize = parseInt(elem.style.fontSize) - 1 + 'px';
        adjust_heights(elem);
      }
      elem.style.display = "block";
    };

    function load_font(font) {
      console.log("loading font: " + font);
      msgs = document.getElementById('msgs');
      WebFont.load({
        google: {
          families: [font]
        },
        active: function() {adjust_heights(msgs);}
      });
      msgs.style.fontFamily = font;
    };

  </script>
</html>
