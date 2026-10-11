import uiautomator2 as u,requests,secrets,time,json,subprocess,os
D=u.connect();O='device-results';base='https://child-safety-api-t76a.onrender.com';key=os.environ['CHILD_PUBLIC_CONFIG'];report=[];token='';device='';observedDevice='';refreshToken=''
def sh(*a):return subprocess.check_output(['adb','shell',*a],text=True)
def snap(n):D.screenshot(O+'/'+n+'.png');open(O+'/'+n+'.xml','w').write(D.dump_hierarchy())
def click(text):
 for _ in range(6):
  x=D(textContains=text)
  if not x.exists:x=D(descriptionContains=text)
  if x.exists:x.click();time.sleep(2);return
  D.swipe_ext('up',scale=.6);time.sleep(1)
 raise RuntimeError('UI control unavailable: '+text)
def history():
 r=requests.get(base+'/api/location/history/'+device,headers={'Authorization':'Bearer '+token},timeout=30);r.raise_for_status();return r.json()
def observe(name,action,seconds=95):
 before=history();action();time.sleep(seconds);after=history();report.append({'scenario':name,'seconds':seconds,'beforeRows':len(before),'afterRows':len(after),'newUpdates':len(after)-len(before),'last':{k:after[0].get(k) for k in ['timestamp','latitude','longitude']} if after else None});snap(name)
email='child-device-test-'+secrets.token_hex(8)+'@example.invalid';password=secrets.token_urlsafe(24)
try:
 r=requests.post('https://identitytoolkit.googleapis.com/v1/accounts:signUp',params={'key':key},json={'email':email,'password':password,'returnSecureToken':True},timeout=30);r.raise_for_status();token=r.json()['idToken'];refreshToken=r.json()['refreshToken']
 requests.get(base+'/',timeout=120).raise_for_status()
 D.app_start('com.childsafety.child_safety_tracker',stop=True);time.sleep(6)
 snap('child-initial')
 import re
 m=re.search(r'[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}',D.dump_hierarchy(compressed=False));observedDevice=m.group(0) if m else ''
 # Native Flutter blank input nodes can be omitted until focused. Use coordinates
 # from the inspected exact API35 v3 pairing screen, scaled to actual display.
 w,h=D.window_size()
 def fill_at(y,value):
  D.click(w*.50,h*y);time.sleep(.4);D(className='android.widget.EditText',focused=True).set_text(value);D.press('back');time.sleep(.5)
 fill_at(.485,key);fill_at(.57,email);fill_at(.655,password)
 D.swipe_ext('up',scale=.45);time.sleep(2);snap('child-form-scrolled')
 # derive empty field from all uncompressed observed hierarchy
 import xml.etree.ElementTree as ET
 root=ET.fromstring(D.dump_hierarchy(compressed=False));nodes=[n for n in root.iter('node') if n.get('class')=='android.widget.EditText' and n.get('enabled')=='true' and n.get('text','')=='']
 if not nodes:raise RuntimeError('Child name field not observed')
 import re
 bb=list(map(int,re.findall(r'\d+',nodes[0].get('bounds'))));D.click((bb[0]+bb[2])//2,(bb[1]+bb[3])//2);D(className='android.widget.EditText',focused=True).set_text('Isolated Android test');D.press('back');snap('child-filled');click('Sign in and pair device');time.sleep(50);snap('child-after-pair')
 devices=requests.get(base+'/api/devices',headers={'Authorization':'Bearer '+token},timeout=120).json();assert len(devices)==1;device=devices[0]['deviceId']
 snap('child-paired');subprocess.run(['adb','emu','geo','fix','73.85','18.52'],check=True);click('Start Tracking')
 for _ in range(3):
  if D(text='While using the app').exists:D(text='While using the app').click();time.sleep(3)
  elif D(text='Allow').exists:D(text='Allow').click();time.sleep(3)
 time.sleep(35);observe('foreground',lambda:None)
 observe('screen-locked',lambda:D.press('power'));D.press('power');D.unlock();time.sleep(3)
 sh('dumpsys','battery','unplug');sh('settings','put','global','low_power','1');observe('battery-saver',lambda:None);sh('settings','put','global','low_power','0');sh('dumpsys','battery','reset')
 observe('internet-cut',lambda:(sh('svc','wifi','disable'),sh('svc','data','disable')));sh('svc','wifi','enable');sh('svc','data','enable');observe('internet-restored',lambda:None)
 D.press('recent');time.sleep(2);D.swipe(.5,.55,.5,.1,duration=.4);observe('swiped-away',lambda:None)
 subprocess.run(['adb','reboot'],check=True);subprocess.run(['adb','wait-for-device'],check=True);time.sleep(55);D=u.connect();D.unlock();observe('restarted-no-launch',lambda:None)
 D.app_start('com.childsafety.child_safety_tracker');time.sleep(5);observe('relaunched-no-start',lambda:None)
finally:
 if token:
  refreshed=requests.post('https://securetoken.googleapis.com/v1/token',params={'key':key},data={'grant_type':'refresh_token','refresh_token':refreshToken},timeout=30)
  if refreshed.status_code==200:token=refreshed.json()['id_token']
  if device or observedDevice:
   r=requests.delete(base+'/api/devices/'+(device or observedDevice),headers={'Authorization':'Bearer '+token},timeout=120);report.append({'cleanupDeviceStatus':r.status_code})
  r=requests.post('https://identitytoolkit.googleapis.com/v1/accounts:delete',params={'key':key},json={'idToken':token},timeout=30);report.append({'cleanupAccountStatus':r.status_code,'error':r.json().get('error',{}).get('message') if r.status_code!=200 else None})
 json.dump(report,open(O+'/child-tracking-result.json','w'),indent=2)
