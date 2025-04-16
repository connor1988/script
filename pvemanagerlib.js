 /usr/share/pve-manager/js/pvemanagerlib.js

{
    itemId: 'Sensors',
    colspan: 2,
        printBar: false,
    title: gettext('温度数据'),
        textField: 'tdata',
renderer: function(value) {
    try {
        var d = JSON.parse(value);
        return d['temp1'] || '-';
    } catch (e) {
        return '-';
    }
}
}
