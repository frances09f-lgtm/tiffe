import uiautomator2 as u,time,os,json,subprocess,re,xml.etree.ElementTree as ET
D=u.connect();O='device-results';os.makedirs(O,exist_ok=True)
def snap(name):
 D.screenshot(O+'/'+name+'.png');open(O+'/'+name+'.xml','w').write(D.dump_hierarchy())
def click(text):
 for _ in range(7):
  x=D(textContains=text)
  if not x.exists:x=D(descriptionContains=text)
  if x.exists:x.click();time.sleep(2);return True
  if D(text='While using the app').exists:D(text='While using the app').click();time.sleep(2);continue
  D.swipe_ext('up',scale=.65);time.sleep(1)
 snap('missing-'+text.replace(' ','-'));return False
D.app_start('com.friday.assistant',stop=True);time.sleep(10)
for _ in range(5):
 if D(text='Allow').exists:D(text='Allow').click();time.sleep(2)
 elif D(text='While using the app').exists:D(text='While using the app').click();time.sleep(2)
 else:break
snap('friday-home')
if not click('Agent Mode'):raise RuntimeError('Agent entry missing')
snap('friday-agent-before')
click('Set up local model');snap('friday-model-before')
if not click('Download and test local model'):raise RuntimeError('Download control missing')
resumes=0
for i in range(240):
 time.sleep(10)
 xml=D.dump_hierarchy()
 if 'Local inference responded' in xml:break
 if 'Connection closed while receiving data' in xml and resumes<2:
  snap('download-interrupted-'+str(resumes));resumes+=1;click('Download and test local model');continue
 if 'failed:' in xml or 'Agent is not ready' in xml:break
 if i%12==0:snap('model-progress-'+str(i))
snap('friday-model-result')
xml=D.dump_hierarchy()
if 'Local inference responded' not in xml:
 open(O+'/friday-outcome.json','w').write(json.dumps({'stage':'model-setup','ready':False}));raise RuntimeError('Local inference not ready, inspect model diagnostic')
D.press('back');time.sleep(2)
# find task field from observed editables
field=D(className='android.widget.EditText');field.set_text('Open YouTube and search for GTA 6');
# Flutter set_text may not open a keyboard. Back without an IME leaves Agent Mode.
if 'mInputShown=true' in D.shell('dumpsys input_method').output:D.press('back')
snap('friday-task-filled')
# UiAutomation suppresses the app accessibility service. End it before the
# real trial. Use the exact Start bounds observed in this actual APK XML.
xml=D.dump_hierarchy(compressed=False)
nodes=[n for n in ET.fromstring(xml).iter('node') if (n.get('text')=='Start' or n.get('content-desc')=='Start') and n.get('clickable')=='true']
if len(nodes)!=1:raise RuntimeError('Unique Start button not observed')
xy=list(map(int,re.findall(r'\d+',nodes[0].get('bounds'))))
D.stop_uiautomator();time.sleep(2)
subprocess.run(['adb','shell','settings','put','secure','enabled_accessibility_services','com.friday.assistant/com.friday.assistant.FridayAccessibilityService'],check=True)
subprocess.run(['adb','shell','settings','put','secure','accessibility_enabled','1'],check=True)
time.sleep(5)
state=subprocess.check_output(['adb','shell','dumpsys','accessibility'],text=True);open(O+'/accessibility-before-trial.txt','w').write(state)
if 'FridayAccessibilityService' not in state:raise RuntimeError('Friday accessibility not bound')
subprocess.run(['adb','shell','input','tap',str((xy[0]+xy[2])//2),str((xy[1]+xy[3])//2)],check=True)
time.sleep(90)
with open(O+'/youtube-after-agent.png','wb') as out:subprocess.run(['adb','exec-out','screencap','-p'],stdout=out,check=True)
subprocess.run(['adb','shell','am','start','-n','com.friday.assistant/.MainActivity'],check=True);time.sleep(3)
with open(O+'/friday-after-agent.png','wb') as out:subprocess.run(['adb','exec-out','screencap','-p'],stdout=out,check=True)
D.start_uiautomator();time.sleep(2)
snap('friday-after-agent-ui')
if not D(descriptionContains='Last decision').exists:click('Agent Mode')
click('Last decision');snap('friday-last-decision')
open(O+'/friday-outcome.json','w').write(json.dumps({'stage':'agent-trial','modelReady':True,'note':'See actual screenshots and hierarchy for outcome'}))
