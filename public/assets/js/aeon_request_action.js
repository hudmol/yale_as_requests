(function(exp) {

    exp.isFindAidView = function() {
        return $('#collection-feed.infinite-record-container').length === 1;
    };

    exp.loadAeonRequestForm = function(recordURI, requestType) {
        $.ajax({
            url: APP_PATH + 'aeon/aeon-request-popup',
            method: 'post',
            data: {
                uri: recordURI,
                request_type: requestType,
                finding_aid_view: exp.isFindAidView(),
            },
            success: function (html) {
                $('#aeon_request_selector_modal .modal-body').html(html);
                new AeonRequestForm(recordURI, $('#aeon_request_selector_modal .modal-body form'));
            },
            error: function (jqXHR, textStatus, errorThrown) {
                $('#aeon_request_selector_modal .modal-body').html(errorThrown);
            }
        });
    };

    const AeonRequestForm = function(recordURI, $form) {
        this.$form = $form;
        this.$modal = $form.closest('.modal');
        this.recordURI = recordURI;
        this.init();
    };

    AeonRequestForm.prototype.init = function() {
        const self = this;

        self.$form.on('click', '.aeon_select_all', function() {
            $('#aeonRequestTable').find('tbody .aeon_requestable_item_input:not(:checked)').trigger('click');
        });

        self.$form.on('click', '.aeon_clear_all', function() {
            $('#aeonRequestTable').find('tbody .aeon_requestable_item_input:checked').trigger('click');
        });

        self.$form.on('click', '.aeon_requestable_item_input', function() {
            self.refreshFormStatus();
        });

        self.$form.find('#request_type').on('change', function() {
            loadAeonRequestForm(self.recordURI, self.$form.find('#request_type').val());
        });

        self.$form.on('submit', function(event) {
            event.preventDefault();

            if (!self.$form.is(':disabled') && $('#aeonRequestFormWrapper form').length === 1) {
                $('#aeonRequestFormWrapper form').submit();
                self.$modal.modal('hide');
            }
        });

        if ($('#aeonRequestTable').find('tbody .aeon_requestable_item_input').length === 1) {
            $('#aeonRequestTable').find('tbody .aeon_requestable_item_input').prop('checked', true);
            self.refreshFormStatus();
        }
    }

    AeonRequestForm.prototype.refreshRequestFormTimeout = undefined;
    AeonRequestForm.prototype.refreshRequestForm = function() {
        const self = this;
        self.$form.find('#aeonFormSubmit').prop('disabled', true);

        if (self.refreshRequestFormTimeout !== undefined) {
            clearTimeout(self.refreshRequestFormTimeout)
        }

        self.refreshRequestFormTimeout = setTimeout(() => {
            $.ajax({
                url: self.$form.attr('action'),
                method: 'post',
                data: new FormData(self.$form[0]),
                processData: false,
                contentType: false,
                success: function(html) {
                    $('#aeonRequestFormWrapper').remove();
                    $(document.body).append('<div id="aeonRequestFormWrapper">');
                    $('#aeonRequestFormWrapper').html(html);
                    self.$form.find('#aeonFormSubmit').prop('disabled', false);
                },
                error: function(jqXHR, textStatus, errorThrown) {
                    $('#aeonFormSubmit').prop('disabled', false);
                    self.$modal.find('.modal-body').html(errorThrown);

                    if (jqXHR.responseText) {
                        self.$modal.find('.modal-body').append('<div>' + jqXHR.responseText + '</div>');
                    }
                }
            });
        }, 500);
    };

    AeonRequestForm.prototype.refreshFormStatus = function() {
        const self = this;
        if (self.$form.find('table tbody .aeon_requestable_item_input:checked').length > 0) {
            self.$form.prop('disabled', false);
            self.$form.find('#aeonFormSubmit').prop('disabled', false);

            self.refreshRequestForm();
        } else {
            self.$form.prop('disabled', true);
            self.$form.find('#aeonFormSubmit').prop('disabled', true);
        }
    };

    exp.AeonRequestForm = AeonRequestForm;
})(window);

$(document).ready(function() {
    $('#disabled-button-wrapper').tooltip({html:true});

    $(document.body).append($('#aeon_request_modal_template').html());

    $('#aeon_request_button').on('click', function() {
        $('#aeon_request_selector_modal .modal-body').empty();
        $('#aeon_request_selector_modal').modal('show');

        loadAeonRequestForm($(this).data('uri'), '');
    });
});
