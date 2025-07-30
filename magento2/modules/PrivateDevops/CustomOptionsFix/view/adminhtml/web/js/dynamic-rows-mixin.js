define([], function () {
    'use strict';

    return function (DynamicRows) {
        return DynamicRows.extend({
            defaults: {
                pageSize: window.customOptionsFixPageSize || 200
            }
        });
    };
});
