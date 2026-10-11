import uiautomator2 as u,time,os,json
D=u.connect();O='device-results';os.makedirs(O,exist_ok=True)
def snap(name):
 D.screenshot(O+'/'+name+'.png');open(O+'/'+name+'.xml','w').write(D.dump_hierarchy())
def click(text):
 for _ in range(7):
  x=D(textContains=text)
  if x.exists:x.click();time.sleep(2);return True
  D.swipe_ext('up',scale=.65);time.sleep(1)
 snap('missing-'+text.replace(' ','-'));return False
D.app_start('com.friday.assistant',stop=True);time.sleep(10)
for _ in range(5):
 if D(text='Allow').exists:D(text='Allow').click();time.sleep(2)
 elif D(text='While using the app').exists:D(text='While using the app').click();time.sleep(2)
 else:break
snap('friday-home')
click('Settings');snap('friday-settings')
if not click('Accessibility Service'):raise RuntimeError('Agent entry missing')
snap('friday-agent-before')
click('Set up local model');snap('friday-model-before')
if not click('Download and test local model'):raise RuntimeError('Download control missing')
for i in range(80):
 time.sleep(10)
 xml=D.dump_hierarchy()
 if 'Local inference responded' in xml:break
 if 'failed:' in xml or 'Agent is not ready' in xml:break
 if i%12==0:snap('model-progress-'+str(i))
snap('friday-model-result')
xml=D.dump_hierarchy()
if 'Local inference responded' not in xml:
 open(O+'/friday-outcome.json','w').write(json.dumps({'stage':'model-setup','ready':False}));raise RuntimeError('Local inference not ready, inspect model diagnostic')
D.press('back');time.sleep(2)
# find task field from observed editables
field=D(className='android.widget.EditText');field.set_text('Open YouTube and search for GTA 6');D.press('back');click('Start')
time.sleep(65);snap('youtube-after-agent')
D.app_start('com.friday.assistant');time.sleep(3)
snap('friday-after-agent')
click('Last decision');snap('friday-last-decision')
open(O+'/friday-outcome.json','w').write(json.dumps({'stage':'agent-trial','modelReady':True,'note':'See actual screenshots and hierarchy for outcome'}))
