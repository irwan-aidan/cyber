# ~/.profile: executed by Bourne-compatible login shells.

red='\e[1;31m'
NC='\e[0m'

if [ "$BASH" ]; then
  if [ -f ~/.bashrc ]; then
    . ~/.bashrc
  fi
fi

mesg n || true
clear
neofetch
echo -e "${blue}Script By VoltNet${NC}"
echo -e "${blue}Premium Multi Port Script${NC}"
echo -e "${blue}Type 'menu' To List Commands${NC}"
