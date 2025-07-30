define([
    'jquery',
    'uiRegistry'
], function ($, registry) {
    'use strict';

    return function (Component) {
        return Component.extend({
            initialize: function () {
                this._super();
                console.log('✅ CustomOptionsFix mixin loaded');

                setTimeout(() => {
                    this.addPageSizeControl();
                }, 1000);

                return this;
            },

            addPageSizeControl: function () {
                $('.admin__field.field.options .field-options .option-box').each(function () {
                    const table = $(this).find('.admin__data-grid-wrap');

                    if (table.length && !$(this).find('.custom-page-size').length) {
                        const control = $(`
                            <div class="custom-page-size" style="margin-bottom: 10px;">
                                <label style="margin-right: 10px;">Show per page:</label>
                                <select>
                                    <option value="50">50</option>
                                    <option value="100">100</option>
                                    <option value="300">300</option>
                                    <option value="500">500</option>
                                    <option value="1000">1000</option>
                                </select>
                            </div>
                        `);

                        control.find('select').on('change', function () {
                            const size = $(this).val();
                            const dataBind = $(table).attr('data-bind');
                            const match = dataBind ? dataBind.match(/scope:\s*'([^']+)'/) : null;

                            if (match && match[1]) {
                                const scope = match[1];
                                const gridScope = registry.get(scope);

                                if (gridScope && gridScope.dataSource && gridScope.dataSource().set) {
                                    gridScope.dataSource().set('params.limit', parseInt(size));
                                    gridScope.dataSource().reload();
                                }
                            }
                        });

                        $(this).prepend(control);
                    }
                });
            }
        });
    };
});
