# erl-socks5-server

# 启动配置

[Unit]
Description=erl socks5 server daemon
After=network.target

[Service]
Type=simple
User=ubuntu
ExecStart=erl -noshell -pa /home/ubuntu/erl-socks5 -s socks5 accept -s init stop

[Install]
WantedBy=multi-user.target
