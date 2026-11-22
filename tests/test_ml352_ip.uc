// ML352 assigned address and DNS stay consistent for wwand's native IPv4 route.
'use strict';

import { eq, done } from './lib/check.uc';
import * as vendors from 'wwand/ncm_vendors.uc';

let recipe = vendors.VENDORS.ml352;
let commands = [];
let rdp_addr = '192.0.2.12';
let rdp_error = false;
let modem = { at: { send: (cmd, cb) => {
	push(commands, cmd);
	if (cmd == 'AT+CGPADDR=1')
		return cb(null, { lines: [ '+CGPADDR: 1,"192.0.2.12"' ] });
	if (cmd == 'AT+CGCONTRDP=1')
		return rdp_error ? cb({ error: 'timeout' }) : cb(null, {
			lines: [ sprintf('+CGCONTRDP: 1,5,"example","%s","","198.51.100.53","198.51.100.54"', rdp_addr) ],
		});
	return cb({ error: 'unexpected_at_command' });
} } };

let result, failure;
recipe.ip_config(modem, 1, { pdp_type: 'ipv4' }, (err, value) => {
	failure = err; result = value;
});
eq(failure, null, 'ML352 accepts its assigned IPv4 address');
eq(result?.ipv4?.addr, '192.0.2.12', 'CGPADDR remains authoritative');
eq(result?.ipv4?.gateway, null, 'CGCONTRDP empty gateway is not invented');
eq(result?.ipv4?.dns, [ '198.51.100.53', '198.51.100.54' ],
	'ML352 provides carrier DNS to native wwand netifd route');
eq(commands, [ 'AT+CGPADDR=1', 'AT+CGCONTRDP=1' ],
	'CID and PDP detail both read through the owned AT engine');

rdp_addr = '203.0.113.7';
recipe.ip_config(modem, 1, { pdp_type: 'ipv4' }, (err, value) => {
	failure = err; result = value;
});
eq(failure, null, 'stale CGCONTRDP does not discard assigned IPv4');
eq(result?.ipv4?.dns, [], 'stale CGCONTRDP DNS cannot reach netifd');

rdp_error = true;
recipe.ip_config(modem, 1, { pdp_type: 'ipv4' }, (err, value) => {
	failure = err; result = value;
});
eq(failure, null, 'missing DNS read does not discard assigned IPv4');
eq(result?.ipv4?.dns, [], 'failed detail read leaves DNS unset');

commands = [];
recipe.ip_config(modem, 2, { pdp_type: 'ipv4' }, (err) => failure = err);
eq(commands, [], 'unknown CID never queries or adopts another PDP');
eq(failure != null, true, 'unknown CID fails closed');

done('test_ml352_ip');
