zc.utcnow_iso = ->
  (new Date()).toJSON()


zc.serialize_form = (el) ->
  pairs = $(el).serializeArray()
  return _.object(_.pluck(pairs, 'name'), _.pluck(pairs, 'value'))


class zc.BlankView extends Backbone.Marionette.ItemView

  template: -> ''


class zc.AppLayout extends Backbone.Marionette.LayoutView

  template: '#app-layout-html'

  regions:
    header: '.app-header'
    contacts: '.app-contacts'
    main: '.app-main'


class zc.HeaderView extends Backbone.Marionette.ItemView

  className: 'header-container tall'
  template: '#header-html'

  events:
    'click .header-btn-configure': (evt) ->
      evt.preventDefault()
      @trigger('click-configure')


class zc.Header extends Backbone.Marionette.Controller

  createView: ->
    identity = @options.app.request('identity')
    view = new zc.HeaderView(model: identity)
    view.on 'click-configure', =>
      configure = new zc.Configure(app: @options.app)
      @options.app.commands.execute('show-main', configure.createView())
    return view


class zc.ConfigureView extends Backbone.Marionette.ItemView

  tagName: 'form'
  className: 'configure-container tall'
  template: '#configure-html'

  events:
    'submit': (evt) ->
      evt.preventDefault()
      data = zc.serialize_form(@el)
      @trigger('save', data)

  onShow: ->
    $input = @$el.find('[name=fingerprint]')
    $input.focus()
    $input[0].setSelectionRange(0, $input.val().length)


class zc.Configure extends Backbone.Marionette.Controller

  createView: ->
    identity = @options.app.request('identity')
    view = new zc.ConfigureView(model: identity)
    view.on 'save', (data) =>
      identity.set('fingerprint', data.fingerprint)
      @options.app.commands.execute('show-main', new zc.BlankView)

    return view


class zc.Transport extends Backbone.Marionette.Controller

  initialize: (options) ->
    @options.app.vent.on('start', _.bind(@connect, @))

  connect: ->
    transport_url = @options.app.request('urls')['transport']
    @ws = new WebSocket(transport_url)
    @ws.onmessage = _.bind(@on_message, @)

  on_message: (evt) ->
    @options.app.vent.trigger('message', JSON.parse(evt.data))

  send: (data) ->
    @ws.send(JSON.stringify(data))


class zc.Persist extends Backbone.Marionette.Controller

  initialize: ->
    @key = @options.key
    @model = @options.model
    value = localStorage.getItem(@key)
    if value
      @model.set(JSON.parse(value))
    @model.on('change', _.bind(@save, @))

  save: ->
    localStorage.setItem(@key, JSON.stringify(@model))


class zc.Receiver extends Backbone.Marionette.Controller

  initialize: ->
    @options.app.vent.on('message', _.bind(@on_message, @))

  on_message: (data) ->
    message_col = @options.app.request('message_collection', data.sender)
    message_col.add(data)


class zc.MessageManager extends Backbone.Marionette.Controller

  initialize: ->
    @collection_map = {}
    @options.app.reqres.setHandler('message_collection',
      _.bind(@get_message_collection, @))

  get_message_collection: (peer) ->
    unless @collection_map[peer]
      @collection_map[peer] = new Backbone.Collection

    return @collection_map[peer]


zc.modules.core = ->
  @models =
    identity: new Backbone.Model
      fingerprint: 'foo'

  @message_manager = new zc.MessageManager(app: @app)

  @persist_identity = new zc.Persist
    key: 'identity'
    model: @models.identity

  zc.set_identity = (fingerprint) =>
    @models.identity.set('fingerprint', fingerprint)

  @app.reqres.setHandler 'identity', => @models.identity

  @transport = new zc.Transport(app: @app)
  @receiver = new zc.Receiver(app: @app)

  @app.commands.setHandler 'send-message', (data) =>
    @transport.send(data)

  @app.commands.setHandler 'show-main', (view) =>
    @layout.main.show(view)

  @app.vent.on 'start', =>
    @layout = new zc.AppLayout(el: @app.request('root_el'))
    @layout.render()

    @header = new zc.Header(app: @app)
    @layout.header.show(@header.createView())

  @models.identity.on 'change', =>
    window.location.reload()