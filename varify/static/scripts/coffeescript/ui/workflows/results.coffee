define [
    'underscore'
    'marionette'
    'cilantro'
    'cilantro/ui/numbers'
    '../tables'
    '../modals'
    '../../models'
    'tpl!templates/count.html'
    'tpl!templates/varify/workflows/results.html'
    'tpl!templates/varify/modals/phenotypes.html'
], (_, Marionette, c, numbers, tables, modal, models, templates...) ->

    templates = _.object ['count', 'results', 'phenotypes'], templates


    class ResultCount extends Marionette.ItemView
        tagName: 'span'

        className: 'result-count'

        template: templates.count

        ui:
            count: '.count'
            label: '.count-label'

        modelEvents:
            'change:objectcount': 'renderCount'

        initialize: ->
            @data = {}
            if not (@data.context = @options.context)
                throw new Error 'context model required'

        onRender: =>
            @renderCount(@model, @model.objectCount if @model.objectCount? or '')

        renderCount: (model, count, options) ->
            sample = null

            if @data.context? and (json = @data.context.get('json'))?
                _.each json.children, (child) ->
                    if child.concept? and child.concept == 2
                        sample = child.children[0].value[0].label

            numbers.renderCount(@ui.count, count)
            @ui.label.text("records in #{ sample or "various samples" }")
            @ui.label.attr('title', sample)

            if sample?
                @ui.label.tooltip({animation: false, html: true, placement: 'bottom', container: 'body'})
            else
                @ui.label.tooltip('destroy')


    ###
    The ResultsWorkflow provides an interface for previewing tabular data,
    mechanisms for customizing the view, and a method for exporting data
    to alternate formats.
    TODO: break out context panel as standalone view

    This view requires the following options:
    - concepts: a collection of concepts that are deemed viewable
    - context: the session/active context model
    - view: the session/active view model
    - results: a Results collection that contains the tabular data
    - exporters: a collection of supported exporters
    - queries: a collection of queries
    ###
    class ResultsWorkflow extends Marionette.Layout
        className: 'results-workflow'

        template: templates.results

        requestDelay: 2500       # In milliseconds
        requestTimeout: 60000    # Max time(ms) for unmonitored exports, 1 minute
        monitorDelay: 500        # In milliseconds
        monitorTimeout: 600000   # Max time(ms) to monitor exports, 10 minutes
        numPendingDownloads: 0
        pageRangePattern: /^[0-9]+(\.\.\.[0-9]+)?$/

        ui:
            contextContainer: '.context-container'
            saveQuery: '.save-query-modal'
            saveQueryToggle: '[data-toggle=save-query]'
            exportOptions: '.export-options-modal'
            exportProgress: '.export-progress-modal'
            toggleFiltersButton: '[data-toggle=context-panel]'
            toggleFiltersIcon: '[data-toggle=context-panel] i'
            toggleFiltersText: '[data-toggle=context-panel] span'
            navbar: '.results-workflow-navbar'
            resultsContainer: '.results-container'
            navbarButtons: '.results-workflow-navbar button'
            loadingOverlay: '.loading-overlay'
            viewPhenotype: '.phenotype-modal .modal-body .span12'

        events:
            'click .export-options-modal [data-save]': 'onExportClicked'
            'click .export-options-modal [data-dismiss=modal]': 'onExportCloseClicked'
            'click [data-toggle=export-options]': 'showExportOptions'
            'click [data-toggle=export-progress]': 'showExportProgress'
            'click #pages-text-ranges': 'selectPagesOption'
            'click [data-toggle=save-query]': 'showSaveQuery'
            'click [data-toggle=context-panel]': 'toggleContextPanelButtonClicked'
            'show.bs.modal .phenotype-modal': 'retrievePhenotypes'
            'hidden.bs.modal .phenotype-modal': 'hidePhenotypes'

        regions:
            columns: '#export-columns-tab'
            count: '.count-region'
            table: '.table-region'
            paginator: '.paginator-region'
            context: '.context-region'
            exportTypes: '.export-type-region'
            exportProgress: '.export-progress-region'
            saveQueryModal: '.save-query-modal'
            resultDetailsModal: '.result-details-modal'

        initialize: ->
            @data = {}
            if not (@data.context = @options.context)
                throw new Error 'context model required'
            if not (@data.view = @options.view)
                throw new Error 'view model required'
            if not (@data.concepts = @options.concepts)
                throw new Error 'concepts collection required'
            if not (@data.results = @options.results)
                throw new Error 'results collection required'
            if not (@data.exporters = @options.exporters)
                throw new Error 'exporters collection required'
            if not (@data.queries = @options.queries)
                throw new Error 'queries collection required'

            $(document).on 'scroll', @onPageScroll
            $(window).resize @onWindowResize

            @data.results.on 'request', @showLoadingOverlay
            @data.results.on 'sync', @hideLoadingOverlay

            @monitors = {}

            # Used to tell if filters were hidden by user clicking the button
            @areFiltersManuallyHidden = false
            # Flag indicating the current visibility of the context panel
            @areFiltersHidden = false

            @on 'router:load', @onRouterLoad
            @on 'router:unload', @onRouterUnload

            c.on 'resultRow:click', (view, result) =>
                @resultDetailsModal.currentView.update(view, result)

        onRouterUnload: =>
            @data.results.trigger('workspace:unload')

        onRouterLoad: =>
            @data.results.trigger('workspace:load')
            @showContextPanel()

        onExportCloseClicked: =>
            _.delay =>
                @columns.currentView.resetFacets()
            , 25

        onExportClicked: =>
            # Don't update the view if the columns haven't changed
            if _.isEqual(_.pluck(@data.view.facets.models, 'id'),
                         _.pluck(@columns.currentView.data.facets.models, 'id'))
                @exportData()
            else
                @data.view.facets.reset(@columns.currentView.data.facets.toJSON())
                # TODO: Notify user if this fails
                @data.view.save({}, {success: @exportData})

        showLoadingOverlay: =>
            if @isClosed? and not @isClosed
                @ui.loadingOverlay.show()

        hideLoadingOverlay: =>
            if @isClosed? and not @isClosed
                @ui.loadingOverlay.hide()

        onWindowResize: =>
            @updateContextPanelOffsets()

        updateContextPanelOffsets: =>
            if not @isClosed? or @isClosed
                return

            # Find the bounds of the results workflow to properly fix the
            # position of the context/filter panel.
            @workflowTopOffset = @$el.offset().top
            @workflowRightOffset = window.innerWidth - (@$el.offset().left + @$el.width())

            @ui.contextContainer.css('top', @workflowTopOffset)
            @ui.contextContainer.css('right', @workflowRightOffset)

        toggleContextPanelButtonClicked: =>
            if @areFiltersHidden
                @areFiltersManuallyHidden = false
                @showContextPanel()
            else
                @areFiltersManuallyHidden = true
                @hideContextPanel()

        showContextPanel: =>
            @areFiltersHidden = false
            @ui.contextContainer.css('display', 'block')
            @ui.resultsContainer.addClass('span9')

            # If we don't update the title by calling fixTitle the tooltip will
            # not respect the attribute change. Also, if we are changing the
            # visibility of the context panel just go ahead and hide the
            # tooltip in case the cause of this was a user click in which case
            # the show/hide filter button is no longer under their mouse.
            @ui.toggleFiltersButton.tooltip('hide')
                .attr('data-original-title', 'Hide Filter Panel')
                .tooltip('fixTitle')

            @ui.toggleFiltersIcon.removeClass('icon-collapse-alt')
            @ui.toggleFiltersIcon.addClass('icon-expand-alt')
            @ui.toggleFiltersText.html('Hide Filters')
            @updateContextPanelOffsets()
            @$('.context').stacked('restack', @$el.height())

        hideContextPanel: =>
            @areFiltersHidden = true
            @ui.contextContainer.css('display', 'none')
            @ui.resultsContainer.removeClass('span9')

            # If we don't update the title by calling fixTitle the tooltip will
            # not respect the attribute change. Also, if we are changing the
            # visibility of the context panel just go ahead and hide the
            # tooltip in case the cause of this was a user click in which case
            # the show/hide filter button is no longer under their mouse.
            @ui.toggleFiltersButton.tooltip('hide')
                .attr('data-original-title', 'Show Filter Panel')
                .tooltip('fixTitle')

            @ui.toggleFiltersIcon.addClass('icon-collapse-alt')
            @ui.toggleFiltersIcon.removeClass('icon-expand-alt')
            @ui.toggleFiltersText.html('Show Filters')

        onPageScroll: =>
            # If the view isn't rendered yet, then don't bother
            if not @isClosed? or @isClosed
                return

            scrollPos = $(document).scrollTop()

            if @ui.navbar.hasClass('navbar-fixed-top')
                if scrollPos < (@navbarVerticalOffset - @topNavbarHeight)
                    # Remove the results navbar from the top
                    @ui.navbar.removeClass('navbar-fixed-top')
                    @ui.contextContainer.css('top', @workflowTopOffset)

                    if not @areFiltersManuallyHidden
                        @showContextPanel()
            else
                if scrollPos >= (@navbarVerticalOffset - @topNavbarHeight)
                    # Move the results navbar to the top
                    @ui.navbar.css('top', @topNavbarHeight)
                    @ui.navbar.addClass('navbar-fixed-top')
                    @ui.contextContainer.css('top', @workflowTopOffset + 35)

                    if not @areFiltersManuallyHidden
                        @hideContextPanel()

        selectPagesOption: ->
            @$('#pages-radio-all').prop('checked', false)
            @$('#pages-radio-ranges').prop('checked', true)
            @$('#pages-text-ranges').val('')

        changeExportStatus: (title, newState) ->
            statusContainer = @$(".export-status-#{ title } .span10")

            statusContainer.children().hide()

            switch newState
                when "pending"
                    statusContainer.find('.pending-container').show()
                when "downloading"
                    statusContainer.find('.progress').show()
                when "error"
                    statusContainer.find('.label-important').show()
                when "success"
                    statusContainer.find('.label-success').show()
                when "timeout"
                    statusContainer.find('.label-timeout').show()

        onExportFinished: (exportTypeTitle) =>
            @numPendingDownloads = @numPendingDownloads - 1
            @$('.export-progress-container .badge-info').html(@numPendingDownloads)

            if @hasExportErrorOccurred(exportTypeTitle)
                @changeExportStatus(exportTypeTitle, "error")
            else if @monitors[exportTypeTitle]["execution_time"] > @monitorTimeout
                @changeExportStatus(exportTypeTitle, "timeout")
            else
                @changeExportStatus(exportTypeTitle, "success")

            # If all the downloads are finished, re-enable the export button
            if @numPendingDownloads is 0
                @$('[data-toggle=export-options]').prop('disabled', false)
                @$('.export-progress-container').hide()

        hasExportErrorOccurred: (exportTypeTitle) ->
            # Since we can't read the content-type of the iframe directly,
            # we need to check to see if the body of the iframe is populated.
            # If it is populated, then an error during export has occurred and
            # the details of that error are contained in the iframe. If all
            # went well, the iframe will have empty head and body elements
            # because the content disposition was attachment.
            @$("#export-download-#{ exportTypeTitle }").contents()[0].body.children.length isnt 0

        checkExportStatus: (exportTypeTitle) =>
            @monitors[exportTypeTitle]["execution_time"] =
                @monitors[exportTypeTitle]["execution_time"] + @monitorDelay

            cookieName = "export-type-#{ exportTypeTitle.toLowerCase() }"

            # Check if the download finished and the cookie was set
            if @getCookie(cookieName) == "complete"
                clearInterval(@monitors[exportTypeTitle]["interval"])
                @setCookie(cookieName, null)
                @onExportFinished(exportTypeTitle)

            # Check for a timeout, if we reached this point, we don't really
            # know what is going on so assume we missed something and the
            # download finished so take the best guess as to the result. Also,
            # check for an error. If an error occurred then kill the monitor
            # and send it to the completed handler.
            else if (@monitors[exportTypeTitle]["execution_time"] > @monitorTimeout or
                     @hasExportErrorOccurred(exportTypeTitle))
                clearInterval(@monitors[exportTypeTitle]["interval"])
                @onExportFinished(exportTypeTitle)

        setCookie: (name, value) ->
            document.cookie= "#{ name }=#{ escape(value) }; path=/"

        getCookie: (name) ->
            # Code adapted from JS on this page:
            #   http://www.w3schools.com/js/js_cookies.asp
            value = document.cookie
            startIndex = value.indexOf(" #{ name }=")

            if startIndex == -1
                startIndex = value.indexOf("#{ name }=")

            if startIndex == -1
                value = null
            else
                startIndex = value.indexOf("=", startIndex) + 1
                endIndex = value.indexOf(";", startIndex)
                if endIndex == -1
                    endIndex = value.length
                value = unescape(value.substring(startIndex, endIndex))

            return value

        startExport: (exportType, pages) =>
            title = @$(exportType).attr('title')
            @changeExportStatus(title, "downloading")

            # Clear the cookie in case the Serrano version is new enough
            # to be setting the cookie in response.
            cookieName = "export-type-#{ title.toLowerCase() }"
            @setCookie(cookieName, null)

            url = @$(exportType).attr('href')
            if url[url.length-1] != "/"
                url = "#{ url }/"
            url = "#{ url }#{ pages }"

            iframe = "<iframe id=export-download-#{ title } src=#{ url } style='display: none'></iframe>"
            @$('.export-iframe-container').append(iframe)

            if @data.exporters.notifiesOnComplete()
                @monitors[title] = {}
                @monitors[title]["execution_time"] = 0
                @monitors[title]["interval"] = setInterval(
                    @checkExportStatus,
                    @monitorDelay,
                    title)
            else
                setTimeout(
                    @onExportFinished,
                    @requestTimeout,
                    title)

        initializeExportStatusIndicators: (selectedTypes) ->
            # Start by hiding all of them
            @$('.export-status-container').children().hide()

            for st in selectedTypes
                @$(".export-status-#{ st.title }").show()

        isPageRangeValid: ->
            if @$('input[name=pages-radio]:checked').val() == "all"
                return true
            else
                pageRange = @$('#pages-text-ranges').val()

                return @pageRangePattern.test(pageRange)

        exportData: (event) =>
            # Clear any of the old iframes. If we are exporting again, these
            # downloads should all have finished based on the UI blocking
            # during active exports.
            @$('.export-iframe-container').empty()

            selectedTypes = @$('input[name=export-type-checkbox]:checked')

            if selectedTypes.length == 0
                @$('#export-error-message').html('An export type must be selected.')
                @$('.export-options-modal .alert-block').show()
            else if not @isPageRangeValid()
                @$('#export-error-message').html('Please enter a valid page range. The page range must be a single page(example: 1) or a range of pages(example: 2...5).')
                @$('.export-options-modal .alert-block').show()
            else
                @numPendingDownloads = selectedTypes.length

                pagesSuffix = ""
                if @$('input[name=pages-radio]:checked').val() != "all"
                    pagesSuffix = @$('#pages-text-ranges').val() + "/"

                # Disable export button until the downloads finish
                @$("[data-toggle=export-options]").prop('disabled', true)
                @$('.export-progress-container').show()
                @$('.export-progress-container .badge-info').html(@numPendingDownloads)

                @ui.exportOptions.modal('hide')

                @initializeExportStatusIndicators(selectedTypes)

                @ui.exportProgress.modal('show')

                # Introduce an artificial delay in between download requests
                # to keep the browser from freaking out about too many
                # simultaneous download requests. We go slower for unmonitored
                # downloads because we don't know for sure when a download
                # completes so we need to give it plenty of time to finish
                # before we make a judgement call on the download. Essentially
                # if the server notifies on complete, we use parallel(to a
                # degree) downloads, otherwise, we take a more serial approach.
                delay = @requestDelay
                if not @data.exporters.notifiesOnComplete()
                    delay = @requestTimeout
                for i in [0..selectedTypes.length-1] by 1
                    @changeExportStatus(@$(selectedTypes[i]).attr('title'), "pending")

                    setTimeout(@startExport, i * delay, selectedTypes[i], pagesSuffix)

        onRender: ->
            # Remove unsupported features from view
            if not c.isSupported('2.1.0')
                @ui.saveQueryToggle.remove()
                @ui.saveQuery.remove()

            @paginator.show new c.ui.Paginator
                model: @data.results

            @count.show new ResultCount
                model: @data.results
                context: @data.context

            @exportTypes.show new c.ui.ExportTypeCollection
                collection: @data.exporters

            @exportProgress.show new c.ui.ExportProgressCollection
                collection: @data.exporters

            @resultDetailsModal.show new modal.ResultDetails

            @saveQueryModal.show new c.ui.EditQueryDialog
                header: 'Save Query'
                view: @data.view
                context: @data.context
                collection: @data.queries

            @context.show new c.ui.ContextPanel
                model: @data.context

            @context.currentView.$el.stacked
                fluid: '.tree-region'

            @table.show new tables.ResultTable
                collection: @data.results
                view: @data.view

            @table.currentView.on 'render', () =>
                @$('.context').stacked('restack', @$el.height())

            @columns.show new c.ui.ConceptColumns
                view: @data.view
                concepts: @data.concepts

            @ui.navbarButtons.tooltip
                animation: false
                placement: 'bottom'

            # Record the vertical offset of the masthead nav bar if we
            # haven't done so already. This is used in scroll calculations.
            if not @navbarVerticalOffset?
                @navbarVerticalOffset = @ui.navbar.offset().top

            # If there is already something fixed to the top, record the height
            # of it so we can account for it in our scroll calculations later.
            if not @topNavbarHeight?
                topElement = $('.navbar-fixed-top')
                if topElement.length
                    @topNavbarHeight = topElement.height()
                else
                    @topNavbarHeight = 0

            if not @workflowTopOffset?
                @updateContextPanelOffsets()

        showExportOptions: ->
            @$('.export-options-modal .alert-block').hide()
            @ui.exportOptions.modal('show')

            if @data.exporters.length is 0
                @$('.export-options-modal .btn-primary').prop('disabled', true)

        showExportProgress: ->
            @ui.exportProgress.modal('show')

        showSaveQuery: =>
            # Opens the query modal without passing a model which assumes a new one
            # will be created based on the current session
            @saveQueryModal.currentView.open()

        renderPhenotypes: (model, response) =>
            return if not @ui.viewPhenotype.is(":visible")
            @ui.viewPhenotype.find(".loading").hide()
            attr = model.attributes
            if attr.hpoAnnotations and attr.hpoAnnotations.length
                attr.hpoAnnotations = _.sortBy(attr.hpoAnnotations, (value) ->
                    parseInt(value.priority) or model.lowestPriority+1)
            if attr.confirmedDiagnoses and attr.confirmedDiagnoses.length
                attr.confirmedDiagnoses = _.sortBy(attr.confirmedDiagnoses, (value) ->
                    parseInt(value.priority) or model.lowestPriority+1)
            if attr.suspectedDiagnoses and attr.suspectedDiagnoses.length
                attr.suspectedDiagnoses = _.sortBy(attr.suspectedDiagnoses, (value) ->
                    parseInt(value.priority) or model.lowestPriority+1)
            if attr.ruledOutDiagnoses and attr.ruledOutDiagnoses.length
                attr.ruledOutDiagnoses = _.sortBy(attr.ruledOutDiagnoses, (value) ->
                    parseInt(value.priority) or model.lowestPriority+1)

            @ui.viewPhenotype.find(".content").html(templates.phenotypes(model.attributes))
            @phenotypeXhr = undefined

        hidePhenotypes: =>
            @phenotypeXhr.abort() if @phenotypeXhr
            @phenotypeXhr = undefined
            @ui.viewPhenotype.find(".content").empty()
            @ui.viewPhenotype.find(".loading").show()

        phenotypesError: (model, response) =>
            return if response.statusText is "abort"
            @ui.viewPhenotype.find(".loading").hide()
            if model?.attributes?.sample_id?
                @ui.viewPhenotype.find(".content").html("<p>An error was encountered. " +
                    "Unable to retrieve phenotypes for sample '#{ model.attributes.sample_id }'.</p>")
            else
                @ui.viewPhenotype.find(".content").html("<p>An error was encountered. No sample is selected.</p>")
            @phenotypeXhr = undefined

        sampleID: =>
            sample = "various samples"

            if @data.context? and (json = @data.context.get('json'))?
                _.each json.children, (child) ->
                    if child.concept? and child.concept == 2
                        sample = child.children[0].value[0].label
            sample

        retrievePhenotypes: =>
            sampleID = @sampleID()
            if sampleID
                # Update the title of the phenotype modal window with the
                # current sample ID
                $('.phenotype-sample-label').html("(#{ sampleID })")

                phenotypes = new models.Phenotype
                    sample_id: sampleID

                @phenotypeXhr = phenotypes.fetch
                    success: @renderPhenotypes
                    error: @phenotypesError
            else
                # Clear the sample label since there is no sample selected.
                $('.phenotype-sample-label').html("")
                @phenotypesError(phenotypes, {})


    { ResultsWorkflow }
