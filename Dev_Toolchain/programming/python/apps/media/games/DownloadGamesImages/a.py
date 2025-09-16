import os
import requests
import time
import re
from pathlib import Path
from bs4 import BeautifulSoup
from PIL import Image
from io import BytesIO
import random
import concurrent.futures
import urllib.parse

# User-Agent to mimic a browser
HEADERS = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
    'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
    'Accept-Language': 'en-US,en;q=0.5',
    'DNT': '1',
    'Connection': 'keep-alive',
    'YOUR_CLIENT_SECRET_HERE': '1',
}

def sanitize_filename(name):
    """Convert game name to filename without spaces"""
    # Remove special characters and replace spaces
    clean_name = re.sub(r'[^\w\s-]', '', name.lower())
    # Replace spaces with nothing
    clean_name = clean_name.replace(' ', '')
    return clean_name

def parse_game_list(tags_content):
    """Parse the game list from the provided content"""
    all_games = []
    
    # Process each line
    for line in tags_content.split('\n'):
        # Skip empty lines, tab indicators, and non-game lines
        if not line or line.startswith('Tab:') or not any(c.isalpha() for c in line):
            continue
        
        # Process the game name
        game_name = line.strip()
        
        # Skip certain entries that appear to be system names or non-games
        skip_prefixes = ['prox', 'win', 'debian', 'esxi', 'fedora', 'ubuntu', 'kali', 'windowserver']
        skip_suffixes = ['iso', 'vhdx', 'vm', 'prox', 'drivers']
        
        if any(game_name.startswith(prefix) for prefix in skip_prefixes) or \
           any(game_name.endswith(suffix) for suffix in skip_suffixes):
            # This looks like a system entry, not a game
            continue
        
        # Add to our list if it's likely a game
        if game_name:
            # Format the game name for better search results
            formatted_name = format_game_name(game_name)
            all_games.append(formatted_name)
    
    print(f"Parsed {len(all_games)} games from the provided list")
    return all_games

def format_game_name(game_name):
    """Format game names to be more readable for searching"""
    # Add spaces between lowercase and uppercase letters
    name = re.sub(r'([a-z])([A-Z])', r'\1 \2', game_name)
    
    # Special replacements
    replacements = {
        'liesofp': 'Lies of P',
        'redout2': 'Redout 2',
        'rimword': 'RimWorld',
        'sims4': 'The Sims 4',
        'ftl': 'FTL: Faster Than Light',
        'codmw': 'Call of Duty: Modern Warfare',
        'codmw3': 'Call of Duty: Modern Warfare 3',
        'ftl': 'FTL: Faster Than Light',
        'batmantts': 'Batman: The Telltale Series',
        'batmantew': 'Batman: The Enemy Within',
        'gtviv': 'Grand Theft Auto IV'
    }
    
    # Check if we have a direct replacement
    if game_name.lower() in replacements:
        return replacements[game_name.lower()]
    
    # Add spaces for common patterns
    name = re.sub(r'(\d+)([a-zA-Z])', r'\1 \2', name)  # Numbers followed by letters
    name = re.sub(r'([a-zA-Z])(\d+)', r'\1 \2', name)  # Letters followed by numbers
    
    # Add spaces for typical abbreviations
    abbr_prefixes = ['cod', 'lego', 'tdp', 'gta']
    for prefix in abbr_prefixes:
        if name.lower().startswith(prefix) and len(name) > len(prefix):
            rest = name[len(prefix):]
            if rest[0].isupper() or rest[0].isdigit():
                name = prefix.upper() + " " + rest
    
    return name
def YOUR_CLIENT_SECRET_HERE(game_name, target_size=(600, 250), timeout=10, max_retries=3):
    """Search for a game image and download it with retries"""
    search_query = f"{game_name} video game logo icon"
    encoded_query = urllib.parse.quote(search_query)
    
    # Try different search engines and approaches
    search_urls = [
        f"https://www.bing.com/images/search?q={encoded_query}&qft=+filterui:aspect-square",
        f"https://duckduckgo.com/?q={encoded_query}&iax=images&ia=images",
        f"https://yandex.com/images/search?text={encoded_query}",
        f"https://www.google.com/search?q={encoded_query}&tbm=isch"
    ]
    
    # Try each search engine with retries
    for attempt in range(max_retries):
        for search_url in search_urls:
            try:
                # Add a randomized user agent for each attempt
                current_headers = HEADERS.copy()
                current_headers['User-Agent'] = random.choice([
                    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
                    'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/15.0 Safari/605.1.15',
                    'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/90.0.4430.212 Safari/537.36',
                    'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:89.0) Gecko/20100101 Firefox/89.0'
                ])
                
                response = requests.get(search_url, headers=current_headers, timeout=timeout)
                
                if response.status_code == 200:
                    soup = BeautifulSoup(response.text, 'html.parser')
                    
                    # Extract image URLs - patterns differ by search engine
                    img_tags = soup.find_all('img')
                    img_urls = []
                    
                    for img in img_tags:
                        # Get all potential URLs
                        src = img.get('src', '')
                        data_src = img.get('data-src', '')
                        srcset = img.get('srcset', '')
                        
                        # Use the best available URL
                        img_url = data_src if data_src else src
                        
                        # Skip base64 encoded images, tiny icons, and empty URLs
                        if img_url and not img_url.startswith('data:') and not img_url.endswith('.svg'):
                            img_urls.append(img_url)
                    
                    # Also look for URLs in JavaScript data
                    script_tags = soup.find_all('script')
                    for script in script_tags:
                        script_content = script.string
                        if script_content:
                            # Simple regex to find image URLs in scripts
                            urls = re.findall(r'https?://[^"\'\s()]+\.(jpg|jpeg|png|webp)', script_content)
                            for url in urls:
                                img_urls.append(url)
                    
                    # Try each image URL until we find a valid one
                    for img_url in img_urls:
                        try:
                            # Complete URL if it's relative
                            if img_url.startswith('//'):
                                img_url = 'https:' + img_url
                            
                            img_response = requests.get(img_url, headers=current_headers, timeout=timeout)
                            if img_response.status_code == 200 and img_response.content:
                                # Check if it's actually an image
                                try:
                                    img = Image.open(BytesIO(img_response.content))
                                    
                                    # Skip if image is too small
                                    if img.width < 16 or img.height < 16:
                                        continue
                                        
                                    # Resize to target size
                                    img = img.resize(target_size, Image.LANCZOS)
                                    
                                    # Convert to PNG
                                    buffer = BytesIO()
                                    img = img.convert('RGBA') if img.mode != 'RGBA' else img
                                    img.save(buffer, format="PNG")
                                    buffer.seek(0)
                                    return buffer.getvalue()
                                except Exception:
                                    continue
                        except Exception:
                            continue
                
            except Exception as e:
                print(f"Error searching {search_url} for {game_name} (attempt {attempt+1}): {str(e)}")
                continue
        
        # Wait before retry
        time.sleep(random.uniform(1, 3))
    
    # If all attempts fail, generate a placeholder image
    return YOUR_CLIENT_SECRET_HERE(game_name, target_size)

def YOUR_CLIENT_SECRET_HERE(game_name, size=(64, 64)):
    """Generate a placeholder image with the first letter or first letters of the game"""
    try:
        # Generate a consistent color based on the game name hash
        name_hash = hash(game_name)
        r = (name_hash % 155) + 50  # Range 50-204
        g = ((name_hash // 10) % 155) + 50
        b = ((name_hash // 100) % 155) + 50
        color = (r, g, b)
        
        img = Image.new('RGB', size, color=color)
        
        # Add first letters of words in game name
        from PIL import ImageDraw, ImageFont
        draw = ImageDraw.Draw(img)
        
        # Try to use a system font or default
        try:
            font = ImageFont.truetype("arial.ttf", size[0] // 3)
        except:
            try:
                # Try other common fonts
                font_options = ["DejaVuSans.ttf", "FreeSans.ttf", "LiberationSans-Regular.ttf", "Verdana.ttf"]
                for font_name in font_options:
                    try:
                        font = ImageFont.truetype(font_name, size[0] // 3)
                        break
                    except:
                        continue
            except:
                font = ImageFont.load_default()
        
        # Get initials (up to 2 characters)
        words = re.findall(r'\w+', game_name)
        if not words:
            letters = "?"
        elif len(words) == 1:
            letters = words[0][0].upper()
        else:
            letters = words[0][0].upper() + words[-1][0].upper()
        
        # Position letter in center
        try:
            # For newer PIL versions
            if hasattr(draw, 'textbbox'):
                bbox = draw.textbbox((0, 0), letters, font=font)
                w, h = bbox[2] - bbox[0], bbox[3] - bbox[1]
            # For older PIL versions
            elif hasattr(draw, 'textsize'):
                w, h = draw.textsize(letters, font=font)
            else:
                w, h = font.getsize(letters)
            
            draw.text(((size[0]-w)/2, (size[1]-h)/2), letters, fill="white", font=font)
        except:
            # Fallback if positioning fails
            draw.text((size[0]/4, size[1]/4), letters, fill="white")
        
        # Add border
        for i in range(2):
            draw.rectangle([i, i, size[0]-i-1, size[1]-i-1], outline="white")
        
        # Convert to PNG
        buffer = BytesIO()
        img.save(buffer, format="PNG")
        buffer.seek(0)
        
        return buffer.getvalue()
    except Exception as e:
        print(f"Error generating placeholder for {game_name}: {e}")
        # Return a minimal valid PNG as last resort
        img = Image.new('RGB', size, color=(100, 100, 100))
        buffer = BytesIO()
        img.save(buffer, format="PNG")
        buffer.seek(0)
        return buffer.getvalue()

def download_worker(args):
    """Worker function for parallel downloads"""
    game_name, images_folder, index, total = args
    
    # Clean filename from the original name (before formatting)
    original_name = game_name
    clean_name = sanitize_filename(original_name.replace(" ", ""))
    file_path = os.path.join(images_folder, f"{clean_name}.png")
    
    # Skip if file already exists
    if os.path.exists(file_path):
        return (original_name, False, "already exists")
    
    try:
        # Add some randomized delay to avoid being blocked
        time.sleep(random.uniform(0.5, 2.0))
        
        print(f"[{index}/{total}] Downloading {game_name}...")
        image_data = YOUR_CLIENT_SECRET_HERE(game_name)
        
        if image_data:
            with open(file_path, 'wb') as f:
                f.write(image_data)
            return (original_name, True, "success")
        else:
            return (original_name, False, "no image found")
    
    except Exception as e:
        return (original_name, False, str(e))

def main():
    # Get downloads folder
    downloads_folder = os.path.join(str(Path.home()), "Downloads")
    
    # Create images folder
    images_folder = os.path.join(downloads_folder, "images")
    os.makedirs(images_folder, exist_ok=True)
    
    print(f"Created images folder at: {images_folder}")
    
    # The content from tags.txt
    tags_content = """Tab: All
13SentinelsAegisRim
advancedwars
alanwake
anothercrabstreasure
Ashen
YOUR_CLIENT_SECRET_HERE
AtelierYumia
Battletoads
BrightMemoryInfinite
YOUR_CLIENT_SECRET_HERE
CrimeBossRockayCity
DeusExInvisibleWar
EnderalForgottenStories
EternalStrands
YOUR_CLIENT_SECRET_HERE
GardenPaws
Hellpoint
inZOI
JurassicWorldEvolution2
KingdomComeDeliverance
legoBatman2
LEGOHarryPotter57
YOUR_CLIENT_SECRET_HERE
MySummerCar
MyTimeatSandrock
Obduction
Omensight
YOUR_CLIENT_SECRET_HERE
PHOGS
YOUR_CLIENT_SECRET_HERE
RajiAnAncientEpic
YOUR_CLIENT_SECRET_HERE
rivals2
SamuraiGunn2
ScarletHollow
ScheduleI
YOUR_CLIENT_SECRET_HERE
SixDaysinFallujah
Skullgirls2ndEncore
Somerville
SpeedRunners
SpellForce3Reforced
SpintiresMudRunner
Steep
SunlessSea
SunlessSkies
SyberiaTheWorldBefore
TDPAHouseofAshes
YOUR_CLIENT_SECRET_HERE
YOUR_CLIENT_SECRET_HERE
YOUR_CLIENT_SECRET_HERE
TheEscapists2
YOUR_CLIENT_SECRET_HERE
ThreeMinutesToEight
TransportFever2
Unrailed
Wanderstop
WobblyLife
Wreckfest
YokusIslandExpress
ZooTycoon

Tab: Finished
brotherstaleoftwosons
YOUR_CLIENT_SECRET_HERE
cocoon
CultoftheLamb
gtviv
highonlife
killerfrequency
lostinplay
mirage
octopathtraveler2
prisonsimulator
RedDeadRedemption
riftapart
slaytheprincess
sleepingdogs
stray
TDPATheDevilinMe
tendates
ThePluckySquire
transistor
xmen

Tab: MyBackup
apk
asus
audiobooks
audioh
autosubs
code
creds
CrimesCSV
ec2
epub2tts
FTPserver
gameinfocsv
gamesaves
gitkraken
gns3
install
installed
ipynb
jellyfin
kubernetes
kuma
linkedinassets
llama3.1
mariadb
meidcat
metasploitble
mining
nginx
nmap
packets
plex
portainer
profile
Projects
prox
prox1
python
redis
speach2text
study
systembackup
titleratings
typescript
vidtrans
vmware
vscode
webinars
Webinars
whisper
win11prox
win11recovery
windowapps
windows11prox
windowsapps
wireshark
wordlists
wordpress
wsl

Tab: meh
AchillesLegendsUntold
Akimbot
AmandatheAdventurer
AngerFoot
Balatro
batmantts
bioshock
bugsnax
control
deadspace
deathmustdie
dirtrally2
dishonored2
doom
DragonBallSparkingZERO
dragonsdogma
dredge
ffx
forgottencity
Frogun
ftl
furi
harvestmoon
hyperlightdrifter
Loopmancer
madmax
minimetro
Mossbook2
MyFriendlyNeighborhood
MyfriendlyNeighborhood
NORCO
norco
oblivion
palworld
pizzatower
punchclub2fastforward
residentevilvillage
returntomonkeyisland
road96
road96mile0
skaterxl
spiritfarer
subnautica
thegreataceattorney
thymsia
YOUR_CLIENT_SECRET_HERE
vampirebloodlines
vampiresurvivors
witcher3
witchfire
Witchfire

Tab: SoulsLike
blasphemous2
eldenring
eldenrings
liesofp
lordsofthefallen
sekiro
sekiroshadowsdietwice

Tab: LocalCoop
awayout
baldursgate3
bioshock2
blur
callofduty2
cuphead
darksidersgenesis
DeathSquared
deeprockgalactic
diablo2
divinityoriginalsin2
DoubleDragonNeon
DuckGame
eastward
YOUR_CLIENT_SECRET_HEREs
FlatHeroes
FlatOut
FlatOut2
FullMetalFuries
GangBeasts
Grounded
grounded
GunfireReborn
HammerwatchII
HeaveHo
HELLDIVERS
hotwheels
HumanFallFlat
YOUR_CLIENT_SECRET_HERE
KillerInstinct
kingdomtwocrowns
YOUR_CLIENT_SECRET_HERE
LEGOBatman3BeyondGotham
LegoCityUndercover
LEGOJurassicWorld
YOUR_CLIENT_SECRET_HERE
LEGOWorlds
LethalLeagueBlaze
LMSH2
YOUR_CLIENT_SECRET_HERE
Magicka
Magicka2
MarioLuigiBrothership
MinecraftDungeons
MoonglowBay
MovingOut2
neonabyss
Nidhogg2
NineParchments
Overcooked2
PainttheTownRed
payday3
prodeus
riskofrain
RiverCityGirls2
RiverCityGirlsZero
sackboy
Screencheat
seaofstars
sonicmania
StickFightTheGame
SuperBombermanR
SUPERBOMBERMANR2
TheJackboxPartyPack7
YOUR_CLIENT_SECRET_HERE
torchlight2
trine2
trine3
trine3fixed
trine4
trine5
UnrulyHeroes

Tab: OporationSystems
debian
esxi
fedora
freeBSD
kali
opensuse
parrotOS
prox2
prox3
prox4
prox5
prox6
prox7
proxandroid
proxconf
proxdump
proxiso
proxisos
proxmoxhyperv
proxmoxvmware
proxproxvm
proxtruenas
proxubuntu
proxubuntuserver
proxwindows11
proxwinserv22
pureOS
ubuntu
ubuntudesktop
ubuntudesktopbasic
ubuntuprox
ubuntuserver
uploadserverftp
whisperPROX
whisperprox
win11drivers
windows11iso
windows11vhdx
windows11vm
windowserver12
windowserver16
windowserver19
windowserver22
windowserver22iso
windowserver22vhdx
winserv22
winservprox
won11prox

Tab: music
music1

Tab: simulators
YOUR_CLIENT_SECRET_HERE
brewmasterbeersimulator
bumsimulator
cafeownersimulation
cheflifesimulator
citieskylines2
cookingsimulator
drift21
frostpunk
GoatSimulator3
hackersimulator
houseflipper
livealive
YOUR_CLIENT_SECRET_HERE
motogp21
pcbuildingsimulator
powerwashsimulator
redout2
rimword
sims4
wreckfest

Tab: repeat
friends
harrypotter
howimetyourmother

Tab: BulkGames
games27
games30gb
games4
games7

Tab: Nintendo/Switch
YOUR_CLIENT_SECRET_HERE
braverlydefault2
deadlink
firemblem3houses
firemblemengage
firemblemwarriors3hopes
kingdomclassic
YOUR_CLIENT_SECRET_HERE
MariovsDonkeyKong
megamanbattlenetwork
PokemonScarletViolet
SONICXSHADOWGENERATIONS
spongbobbfbbr
supermariorpg
supermariowonder
YOUR_CLIENT_SECRET_HERE
TLoZEchoesofWisdom
xenobladechronicles
zeldalinktothepast

Tab: shooters
alphaprotocol
battlefield1
battlefieldbadcompany2
battlefieldhardline
battlefieldv
binarydomain
codadvancedwarfare
codblackops
codblackops2
codblackops3
codghosts
codinfinfinitewarfare
codinfinitewarfare
codmw
codmw3
codvanguard
codww2
deadisland2
DOOMEternal
doomethernal
enterthegungeon
escapefromtarkov
exithegungeon
farcryprimal
FlintlockTheSiegeofDawn
Immortalsofaveum
immortalsofaveum
metroexodus
metroredux
moderwarfare2
myfriendpedro
NexMachina
prey
rage2
rainbowsixsiege
readyornot
YOUR_CLIENT_SECRET_HERE
RESEARCHandDESTROY
resistance2
returnal
robocoproguecity
seriousam4
showgunners
singularity
sniperelite2
sniperelite3
sniperghostwarrior2
YOUR_CLIENT_SECRET_HERE
superseducer2
systemshock
systemshockremake
theascent
thesurge2
trinityfusion
vanquish
VoidBastards
VoidBastardsBangTydy
wildlands
wolfenstein2

Tab: OpenWorld
aspacefortheunbound
Avowed
ChicoryAcolorfulTale
cloudpunk
DaysGone
deadrising2
DeadRising4
desperados3
dordogne
driversanfrancisco
DYSMANTLE
Eastshade
YOUR_CLIENT_SECRET_HERE
fallout4
FalloutLondon
GenerationZero
godofwar
gothic2
GreakMemoriesofAzur
greedfall
hellblade2
immortalsfenyxrising
YOUR_CLIENT_SECRET_HERE
YOUR_CLIENT_SECRET_HERE
judgment
justcause3
KingdomComeDeliverance2
kingdomofamalur
littlekittybigcity
mafia
YOUR_CLIENT_SECRET_HERE
YOUR_CLIENT_SECRET_HERE
nier
nobodysavedtheworld
nobodysavestheworld
nomoreheroes3
NoStraightRoads
okamihd
outerworld
Outward
ridersrepublic
risen2
risen3
Sable
sable
saintsrow2
saintsrow3
scarface
SenuasSagaHellblade2
SonicUnleashed
spacefortheunbound
spiderman2
strangerofparadaise
sunhaven
sunsetoverdive
TalesofArise
talesofarise
tchia
thegodfather
thegunk
theinvincible
ThePathless
thepathless
trektoyomi
vampyr
weirdwest
Yakuza0
yakuza0
yakuza3
yakuza3remasterd
yakuza4
Yakuza5
yakuza5
Yakuza6
yakuza6thesongodlife
YakuzaKiwami
yakuzakiwami
YakuzaKiwami2
yakuzakiwami2
YakuzaLikeaDragon
yakuzalikeadragon

Tab: HackNslash
banishers
bayonetta2
Bayonetta3
bayonetta3
BlazBlueCentralFiction
YOUR_CLIENT_SECRET_HERE
curseofthedeadgods
devilmaycry4
doubledragongaiden
evilwest
fatesamurairemnant
fistforgedinshadow
fistforgedinshadowtorch
fury
hellbladesenuasacrifice
Indivisible
legendoftianding
LollipopChainsawRePOP
metalgearsolidmaster
MetalHellsinger
metalhellsinger
midnightfightexpress
repellafella
scarletnexus
scarsabove
skulheroslayer
soulstice
steelrising
talesofberseria
talesofvesperia
tenseiv
thedarkness
thedarkness2
thelastfaith
thelegendoftianding
themageseeker
thepunisher
TMNTSplinteredFate
torchlight3
wanderingsword
YsIXMonstrumNox

Tab: Chill
bramble
CardShark
CitizenSleeper
cobletcore
covergence
cultofthelamb
davethediver
gameaboutdiggingahole
goodbyevolcanohigh
hades2
inscryption
islets
Islets
Littlewood
Melatonin
moonstoneisland
myst
ninokuni
nocturnal
notforbroadcast
oddworldsoulstorm
oxenfree2
pentiment
persona4
planetcoaster
planetoflana
sludgelife2
SteinsGateElite
tellmewhy
tetriseffect
theartfulescape
tinykin
ugly
unpacking
venba

Tab: StoryDriven
AITHESOMNIUMFILES
AlanWake2
ancestorshumankind
asduskfalls
atdeadofnight
atlasfallen
batmantew
beyond2souls
Bully
CassetteBeasts
chainedechoes
childrenofthesun
cosmicwheelsisterhood
covergencealolstory
crisiscorefinalfantasy7
CrisTales
CrossCode
Danganronpa
darkpicturesanthology
detroitbecomehuman
deusex
deusexhuman
eiyudenchromicle
eiyudenchroniclerising
elpasoelswere
enderliles
Enshrouded
enslaved
erica
eternalcylinder
firstdatelatetodate
fivedates
fuga
gerda
Griftlands
haveanicedeath
highlandsong
indika
jusant
lateshift
lifeistrangeremasterd
loreleiandtheLaserEyes
LostRecordsBloomRage
lovetooeasily
marvel
masseffect2
MetalGearSolid2
MetalGearSolid3
MetaphorReFantazio
miandthedragonprincess
NeoCab
neotheworldendswithyou
neva
NightCall
NobodyWantstoDie
Observation
observer
plagtalerequirm
pseudoregalia
YOUR_CLIENT_SECRET_HERE
shadowgambit
YOUR_CLIENT_SECRET_HERE
YOUR_CLIENT_SECRET_HERE
YOUR_CLIENT_SECRET_HERE
signalis
YOUR_CLIENT_SECRET_HERE
tellinglies
thebunker
thecaseofthegoldenidol
thecomplex
TheLegendofHeroes
YOUR_CLIENT_SECRET_HERE
themedium
theradstringclub
thesilentage
TheSpiritandtheMouse
TheWildatHeart
thexpanse
thisbedwemade
tloh
YOUR_CLIENT_SECRET_HERE
trianglestrategy
TroverSavestheUniverse
twinmirrors
valkyriachronicles4
videoverse

Tab: platformers
americanarcedia
artfulescape
AstralAscent
blackskylands
blacktail
bombrushcyberfunk
catherine
chantsofsennaar
circuselectricque
circuselectrique
cosmicshake
Creaks
GatoRoboto
ghostrick
ghostrunner
ghostrunner2
kazeandthewildmasks
megamanxdive
MinuteofIslands
Octogeddon
Onirism
pacmanworldrepac
priceofpersia
sanabi
solarash
sonicolors
sonicsuperstarts
thecub
tornaway
trepang2
turok
UNSIGHTED
wsl
profile
study
windowsapps
MonsterHunterRise
ShadowOfTheColossus
gamesaves
Blanc
webinars2
Kona2
DragonBallFighterZ
theCastingofFrankSton
DragonBallXenoverse2
DragonBallZKakarot
KaotheKangaroo
ENADreamBBQ
DungeonsOfHinterberg
DegreesofSeparation
Selfloss
AILIMIT
EnGarde
WizardwithaGun
OpenRoads
1000xRESIST
SquirrelwithaGun
PokemonSwordShield
YOUR_CLIENT_SECRET_HERE
FARChangingTides
KingsBounty2
MortalKombat1
LuigisMansion3
LuigisMansion2HD
Nioh
Nioh2
creds
BluePrince
SouthofMidnight
DevilMayCryHDCollection
DeusExInvisibleWar
YOUR_CLIENT_SECRET_HERE
visionsofmana"""
    
    # Parse the game list
    games = parse_game_list(tags_content)
    
    # Remove duplicates while preserving order
    unique_games = []
    seen = set()
    for game in games:
        normalized = game.lower().replace(" ", "")
        if normalized not in seen:
            seen.add(normalized)
            unique_games.append(game)
    
    print(f"Found {len(unique_games)} unique games after deduplication")
    
    # Prepare arguments for parallel processing
    total_games = len(unique_games)
    worker_args = [(game, images_folder, i+1, total_games) 
                  for i, game in enumerate(unique_games)]
    
    # Download images in parallel
    with concurrent.futures.ThreadPoolExecutor(max_workers=4) as executor:
        results = list(executor.map(download_worker, worker_args))
    
    # Print summary
    successes = sum(1 for _, success, _ in results if success)
    print(f"\nDownload complete!")
    print(f"Successfully downloaded: {successes}/{total_games} images")
    
    # Print failures if any
    failures = [(name, reason) for name, success, reason in results if not success]
    if failures:
        print("\nFailed downloads:")
        for name, reason in failures:
            print(f"- {name}: {reason}")

if __name__ == "__main__":
    main()