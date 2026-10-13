import 'package:flutter_test/flutter_test.dart';
import 'package:tiffe/staff/staff_policy.dart';
void main(){
 test('staff access has no self-selected role',(){expect(StaffPolicy.canEnter('customer'),false);expect(StaffPolicy.canEnter(null),false);expect(StaffPolicy.canEnter('owner'),true);});
 test('delivery sees assigned orders only and cannot assign or read customers',(){expect(StaffPolicy.visible('delivery','r1',{'assigned_to':'r2'}),false);expect(StaffPolicy.visible('delivery','r1',{'assigned_to':'r1'}),true);expect(StaffPolicy.canAssign('delivery'),false);expect(StaffPolicy.canCustomers('delivery'),false);});
 test('delivery only existing authorized transition',(){expect(StaffPolicy.next('delivery',{'status':'Packed'}),null);expect(StaffPolicy.next('delivery',{'status':'Out for Delivery'}),'Delivered');});
}
