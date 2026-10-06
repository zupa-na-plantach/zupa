Trestle.resource(:trips) do
  collection do
    Trip
      .includes(groups: [trip_destinations: :location])
      .order(date: :desc)
  end

  routes do
    patch :select_template, on: :member
    patch :refresh_snapshots, on: :member
  end

  menu do
    item :trips, icon: "fa fa-car-side", badge: Trip.count, priority: 20, group: :trips
  end

  table do
    column :date
    column :organiser
    column :preparation_template, header: I18n.t("admin.preparation_templates.columns.template") do |trip|
      trip.preparation_template&.name
    end
    column :active
    actions do |toolbar, trip|
      toolbar.delete unless trip.past_date?
    end
  end

  form do |trip|
    # from https://github.com/TrestleAdmin/trestle/blob/v0.9.7/lib/trestle/resource/builder.rb#L20
    # admin.actions.delete works on the whole resource so it needs to be added back for the instances that are not past their date
    instance.past_date? ? admin.actions.delete(:destroy) : admin.actions.push(:destroy)

    tab :trip do
      check_box :active
      date_field :date, disabled: trip.past_date?
      # The spreadsheet only owns sheet-managed trips; hide the URL on wizard-managed ones.
      if trip.new_record? || trip.sheet?
        url_field :source_spreadsheet_url, disabled: trip.past_date?
      end
      select :admin_user_id, AdminUser.all,
        selected: trip.admin_user_id || current_user.id, disabled: trip.past_date?

      # Action row + info box render only for persisted trips; new trips keep the
      # default Trestle top-toolbar save. The whole row lives inside the <form>,
      # so the Save submit and the (rails-ujs) refresh/delete links sit together
      # on the white card. The top toolbar is suppressed by the edit/show view
      # overrides in app/views/admin/trips/.
      if trip.persisted?
        wizard_label = trip.sheet? ? I18n.t("admin.trips.switch_to_wizard.button") : I18n.t("admin.trips.edit_in_wizard.button")
        wizard_data = trip.sheet? ? {confirm: I18n.t("admin.trips.switch_to_wizard.confirm")} : {}
        # Wizard editing is behind the :trip_builder flag, per logged-in user.
        show_wizard = !trip.past_date? && Flipper.enabled?(:trip_builder, current_user)

        buttons = []
        unless trip.past_date?
          buttons << link_to(I18n.t("admin.trips.refresh_snapshots.button"),
            "/admin/trips/#{trip.id}/refresh_snapshots",
            method: :patch, class: "btn btn-warning",
            data: {confirm: I18n.t("admin.trips.refresh_snapshots.confirm")})
        end
        if show_wizard
          buttons << link_to("/admin/trip_builder?trip_id=#{trip.id}",
            class: "btn tb-magic", data: wizard_data) {
            (icon("fa fa-magic") + " " + wizard_label).html_safe
          }
        end
        buttons << content_tag(:button, I18n.t("admin.buttons.save", model_name: Trip.model_name.human),
          type: "submit", class: "btn btn-success")

        unless trip.past_date?
          # Separator + smaller, set-apart destroy action.
          buttons << content_tag(:span, "", style: "align-self: stretch; border-left: 1px solid #ddd; margin: 0 0.25rem;")
          buttons << link_to("/admin/trips/#{trip.id}", method: :delete, class: "btn btn-danger btn-sm",
            data: {confirm: I18n.t("admin.buttons.delete_confirm", default: "Czy na pewno usunąć ten wyjazd?")}) {
            (icon("fa fa-trash") + " " + I18n.t("admin.buttons.delete", default: "Usuń %{model_name}", model_name: Trip.model_name.human)).html_safe
          }
        end

        # ✨ shimmer on the wizard button — a sweeping highlight + soft glow.
        concat content_tag(:style, <<~CSS.html_safe)
          .tb-magic {
            position: relative; overflow: hidden; border: none; color: #fff;
            background: linear-gradient(135deg, #a55eea, #8854d0);
            animation: tb-glow 2.8s ease-in-out infinite;
          }
          .tb-magic:hover, .tb-magic:focus {
            color: #fff; background: linear-gradient(135deg, #b06fef, #9560e0);
          }
          .tb-magic::after {
            content: ""; position: absolute; top: 0; left: -150%; width: 60%; height: 100%;
            background: linear-gradient(120deg, transparent, rgba(255,255,255,0.65), transparent);
            transform: skewX(-20deg); animation: tb-shimmer 2.8s ease-in-out infinite;
          }
          @keyframes tb-shimmer { 0% { left: -150%; } 55% { left: 150%; } 100% { left: 150%; } }
          @keyframes tb-glow {
            0%, 100% { box-shadow: 0 0 0 rgba(165, 94, 234, 0); }
            55% { box-shadow: 0 0 14px rgba(165, 94, 234, 0.75); }
          }
        CSS

        concat content_tag(:div, safe_join(buttons),
          style: "margin-top: 1.5rem; display: flex; flex-wrap: wrap; gap: 0.5rem; align-items: center;")

        # Info box: what the data-changing buttons do.
        save_info = if trip.past_date?
          I18n.t("admin.trips.save_info.past")
        elsif trip.sheet?
          I18n.t("admin.trips.save_info.sheet")
        else
          I18n.t("admin.trips.save_info.manual")
        end
        edit_info = trip.sheet? ? I18n.t("admin.trips.edit_info.sheet") : I18n.t("admin.trips.edit_info.manual")
        info_lines = []
        unless trip.past_date?
          info_lines << content_tag(:p, (content_tag(:strong, I18n.t("admin.trips.refresh_snapshots.button") + ": ") + I18n.t("admin.trips.refresh_snapshots.description")).html_safe, style: "margin: 0 0 0.25rem;")
        end
        if show_wizard
          info_lines << content_tag(:p, (content_tag(:strong, wizard_label + ": ") + edit_info).html_safe, style: "margin: 0 0 0.25rem;")
        end
        info_lines << content_tag(:p, (content_tag(:strong, I18n.t("admin.buttons.save", model_name: Trip.model_name.human) + ": ") + save_info).html_safe, style: "margin: 0;")
        concat content_tag(:div, safe_join(info_lines),
          class: "well", style: "margin-top: 1rem; padding: 0.75rem 1rem; background: #f7f7f7; border: 1px solid #eee; border-radius: 4px; color: #666;")
      end
    end

    tab :preview, label: I18n.t("admin.trip_preview.tab") do
      unless trip.new_record?
        render inline: <<~HTML
          <div class="phone-frame"
               data-controller="trip-preview"
               data-trip-preview-trip-id-value="#{trip.id}"
               data-trip-preview-load-label-value="#{I18n.t("admin.trip_preview.load")}"
               data-trip-preview-loading-label-value="#{I18n.t("admin.trip_preview.loading")}"
               data-trip-preview-reload-label-value="#{I18n.t("admin.trip_preview.reload")}"
               data-trip-preview-reloading-label-value="#{I18n.t("admin.trip_preview.reloading")}"
               data-trip-preview-error-label-value="#{I18n.t("admin.trip_preview.error")}"
               data-trip-preview-placeholder-label-value="#{I18n.t("admin.trip_preview.placeholder")}">
            <div class="phone-frame__controls">
              <button class="btn btn-success" data-trip-preview-target="loadButton" data-action="trip-preview#load">
                #{I18n.t("admin.trip_preview.load")}
              </button>
              <button class="btn btn-success" data-trip-preview-target="reloadButton" data-action="trip-preview#reload" style="display:none">
                #{I18n.t("admin.trip_preview.reload")}
              </button>
              <p class="phone-frame__note">#{I18n.t("admin.trip_preview.expires_note")}</p>
            </div>
            <div class="phone-frame__notch"></div>
            <div class="phone-frame__screen">
              <iframe class="phone-frame__iframe" data-trip-preview-target="iframe" style="display:none"></iframe>
              <div class="phone-frame__placeholder" data-trip-preview-target="placeholder">
                #{I18n.t("admin.trip_preview.placeholder")}
              </div>
            </div>
          </div>
        HTML
      end
    end

    tab :ksiazki, label: I18n.t("admin.trips.tabs.ksiazki") do
      unless trip.new_record?
        container do |c|
          groups_with_rows = trip.groups.map do |group|
            rows = group.trip_destinations.flat_map do |td|
              person_rows = td.trip_destination_people
                .where.not(book_preferences: [nil, ""])
                .map { |p| {location: td.name, person: p, preferences: p.book_preferences} }
              # Group (estimated) locations have no Person cards; their readers'
              # book wishes live as one free-text blob on the location itself.
              if td.book_preferences.present?
                person_rows + [{location: td.name, person: nil, preferences: td.book_preferences}]
              else
                person_rows
              end
            end
            [TripGroupDecorator.new(group), rows]
          end.reject { |_g, rows| rows.empty? }

          card do
            if groups_with_rows.empty?
              content_tag(:p, I18n.t("admin.trips.ksiazki.empty"), style: "margin: 1rem; color: #666;")
            else
              sections = groups_with_rows.map { |group, rows|
                header = content_tag(:thead) do
                  content_tag(:tr) do
                    safe_join([
                      content_tag(:th, I18n.t("admin.trips.ksiazki.columns.location")),
                      content_tag(:th, I18n.t("admin.trips.ksiazki.columns.person")),
                      content_tag(:th, I18n.t("admin.trips.ksiazki.columns.preferences"))
                    ])
                  end
                end

                body = content_tag(:tbody) do
                  safe_join(rows.map { |r|
                    content_tag(:tr) do
                      person_cell = if r[:person]
                        admin_link_to(r[:person].first_name, r[:person], admin: :people)
                      else
                        content_tag(:em, I18n.t("admin.trips.ksiazki.whole_location"))
                      end
                      safe_join([
                        content_tag(:td, r[:location]),
                        content_tag(:td, person_cell),
                        content_tag(:td, simple_format(r[:preferences]))
                      ])
                    end
                  })
                end

                crew = group.all_volunteer_names
                heading = crew.any? ? "#{group.name} — #{crew.join(", ")}" : group.name
                content_tag(:h3, heading, style: "margin-top: 1.5rem;") +
                  content_tag(:table, header + body, class: "table table-striped", style: "width: 100%;")
              }

              content_tag(:div, safe_join(sections), id: "books-content") +
                content_tag(:div, class: "btn-group", style: "margin-top: 1rem;") {
                  content_tag(:button, I18n.t("admin.trips.ksiazki.print"),
                    onclick: "event.preventDefault(); (function() {
                      var content = document.getElementById('books-content').innerHTML;
                      var w = window.open('', '_blank');
                      w.document.write('<html><head><title>#{I18n.t("admin.trips.ksiazki.print_title")}</title><style>' +
                        '@page { size: A4 landscape; margin: 1cm; }' +
                        'body { font-family: -apple-system, BlinkMacSystemFont, sans-serif; margin: 0; padding: 1cm; }' +
                        'h3 { margin-top: 1.5em; }' +
                        'table { width: 100%; border-collapse: collapse; margin: 0.5em 0; page-break-inside: avoid; }' +
                        'th, td { border: 1px solid #ccc; padding: 0.5em; vertical-align: top; }' +
                        'th { background-color: #f7f7f7; font-weight: bold; }' +
                        '</style></head><body>' + content + '</body></html>');
                      w.document.close();
                      w.focus();
                      w.print();
                    })()",
                    class: "btn btn-success print-button no-print")
                }
            end
          end
        end
      end
    end

    tab :przygotowania do
      unless trip.new_record?
        container do |c|
          trip_json = TripJsonBuilder.build(trip)

          templates = PreparationTemplate.order(:name)
          current_template = trip.preparation_template

          default_suffix = I18n.t("admin.preparation_templates.labels.default_suffix")
          template_options = templates.map { |t| [t.name + (t.default? ? " #{default_suffix}" : ""), t.id] }
          selected_template_id = current_template&.id

          content_html = current_template&.content_html
          rendered_preview = if content_html
            begin
              Mustache.render(content_html, trip_json)
            rescue => e
              "<pre style='color:red;'>#{ERB::Util.html_escape(e.message)}</pre>"
            end
          else
            ""
          end

          card do
            # Template selector
            content_tag(:div, class: "preparation-template-selector", style: "margin-bottom: 1rem;") do
              options_html = safe_join(
                [content_tag(:option, I18n.t("admin.preparation_templates.labels.no_template"), value: "")] +
                  template_options.map { |label, id|
                    content_tag(:option, label, value: id, selected: id == selected_template_id)
                  }
              )

              content_tag(:label, I18n.t("admin.preparation_templates.labels.template_selector") + ": ", for: "template-select", style: "font-weight: bold; margin-right: 0.5rem;") +
                content_tag(:select, options_html,
                  id: "template-select", class: "form-control",
                  style: "display: inline-block; width: auto;",
                  data: {trip_id: trip.id})
            end
          end

          card do
            content_tag(:p, "<strong>#{I18n.t("admin.preparation_templates.labels.preview")}:</strong>".html_safe) +
              content_tag(:div, rendered_preview.html_safe, id: "rendered-preview",
                style: "margin-top: 1rem; border: 1px solid #ccc; padding: 1rem; max-height: 400px; overflow: auto;") +
              content_tag(:div, class: "btn-group", style: "margin-top: 1rem;") {
                content_tag(:button, I18n.t("admin.preparation_templates.labels.print"),
                  onclick: "event.preventDefault(); (function() {
                    var content = document.getElementById('rendered-preview').innerHTML;
                    var w = window.open('', '_blank');
                    w.document.write('<html><head><title>Przygotowania</title><style>' +
                      '@page { size: A4 landscape; margin: 1cm; }' +
                      'body { font-family: -apple-system, BlinkMacSystemFont, sans-serif; margin: 0; padding: 1cm; }' +
                      'table { width: 100%; border-collapse: collapse; margin: 1em 0; page-break-inside: avoid; }' +
                      'th, td { border: 1px solid #ccc; padding: 0.5em; vertical-align: top; }' +
                      'th { background-color: #f7f7f7; font-weight: bold; }' +
                      '.group-table-footer { background-color: #f5f5f5; }' +
                      '</style></head><body>' + content + '</body></html>');
                    w.document.close();
                    w.focus();
                    w.print();
                  })()",
                  class: "btn btn-success print-button no-print")
              }
          end
        end
      end
    end

    # TEMPORARY — DB audit tab, remove after deploy verification
    tab :db_audit, label: "Audyt DB" do
      unless trip.new_record?
        container do
          fields = [
            [:person_count, "Osoby"],
            [:soups, "Zupy"],
            [:sandwiches, "Kanapki"],
            [:chocolates, "Czekolady"],
            [:waters, "Wody"],
            [:provisions, "Prowiant"],
            [:books, "Książki"],
            [:package_count, "Paczki"],
            [:animal_count, "Zwierzęta"]
          ]

          settings = AppSetting.instance

          compute_current = lambda do |location|
            if location.estimated?
              epc = location.estimated_person_count.to_i
              {
                person_count: epc,
                soups: 0,
                sandwiches: epc * settings.sandwiches_per_person,
                chocolates: epc * settings.chocolates_per_person,
                waters: epc * (settings.sparkling_water_per_person + settings.still_water_per_person),
                provisions: 0,
                books: location.book_preferences.present? ? 1 : 0,
                package_count: 0,
                animal_count: location.active_animals.size
              }
            else
              people = location.active_people
              {
                person_count: people.size,
                soups: people.sum(&:soups),
                sandwiches: people.sum(&:sandwiches),
                chocolates: people.sum(&:chocolates),
                waters: people.sum { |p| p.sparkling_water + p.still_water },
                provisions: people.count(&:long_term_provisions),
                books: people.count { |p| p.book_preferences.present? },
                package_count: people.sum(&:packed_package_count),
                animal_count: location.active_animals.size
              }
            end
          end

          sections = trip.groups.map do |group|
            destination_tables = group.trip_destinations.includes(:location).map do |td|
              current = compute_current.call(td.location)

              header_row = content_tag(:thead) do
                content_tag(:tr) do
                  safe_join([
                    content_tag(:th, "Pole"),
                    content_tag(:th, "Zapisane (DB column)"),
                    content_tag(:th, "Obecny stan (live z Person/Animal)"),
                    content_tag(:th, "Różnica")
                  ])
                end
              end

              body_rows = fields.map do |field, label|
                stored = td.public_send(field).to_i
                live = current[field].to_i
                diff = live - stored
                cell_style = (diff != 0) ? "background-color: #fff3cd;" : ""
                diff_label = if diff == 0
                  "—"
                elsif diff > 0
                  "+#{diff}"
                else
                  diff.to_s
                end
                content_tag(:tr, style: cell_style) do
                  safe_join([
                    content_tag(:td, label),
                    content_tag(:td, stored.to_s),
                    content_tag(:td, live.to_s),
                    content_tag(:td, diff_label)
                  ])
                end
              end

              location_type = td.location.estimated? ? "grupowe" : "zwykłe"
              content_tag(:h4, "#{td.name} (#{location_type})", style: "margin-top: 1.5rem;") +
                content_tag(:table, header_row + content_tag(:tbody, safe_join(body_rows)),
                  class: "table table-striped", style: "width: 100%;")
            end

            content_tag(:h3, "GR #{group.number}: #{group.all_volunteer_names.join(", ")}", style: "margin-top: 2rem;") +
              safe_join(destination_tables)
          end

          card do
            content_tag(:p,
              "Tymczasowa zakładka — porównuje zapisane wartości na trip_destinations (kolumny w DB) z tym, co byłoby teraz wyliczone z Person/Animal.",
              style: "color: #666; margin: 1rem;") +
              safe_join(sections)
          end
        end
      end
    end
  end

  controller do
    def create
      result = Trips::CreateTrip.new.call(trip_params)

      if result == true
        flash[:message] = flash_message("create.success", title: "", message: "")
      else
        flash[:error] = error_message(result[:not_found]).html_safe
      end

      redirect_to "/admin/trips"
    rescue Trips::SpreadsheetAccessError, Trips::EmptyTripDataError => e
      flash[:error] = e.message
      redirect_to "/admin/trips"
    end

    def update
      trip = Trip.find(params[(:id)])
      result = if trip.past_date?
        trip.update(active: trip_params[:active])
      elsif trip.manual?
        # Wizard-managed: save metadata only, never re-parse a spreadsheet.
        trip.update(trip_params.except(:source_spreadsheet_url))
      else
        # Sheet-managed: re-parse + rebuild from the spreadsheet.
        Trips::UpdateTrip.new.call(id: params[:id], params: trip_params)
      end

      if result == true
        flash[:message] = flash_message("update.success", title: "", message: "")
      elsif result == false
        # Metadata-only branches (manual/past) return a boolean from #update;
        # surface the model's validation errors instead of the sheet-only :not_found shape.
        flash[:error] = trip.errors.full_messages.join(", ")
      else
        flash[:error] = error_message(result[:not_found]).html_safe
      end

      redirect_to "/admin/trips/#{params[:id]}"
    rescue Trips::SpreadsheetAccessError, Trips::EmptyTripDataError => e
      flash[:error] = e.message
      redirect_to "/admin/trips/#{params[:id]}"
    end

    def refresh_snapshots
      trip = Trip.find(params[:id])
      if trip.past_date?
        flash[:error] = I18n.t("admin.trips.refresh_snapshots.past_trip_error")
      else
        Trips::RefreshSnapshots.new.call(trip: trip)
        flash[:message] = I18n.t("admin.trips.refresh_snapshots.success")
      end
      redirect_to "/admin/trips/#{trip.id}"
    end

    def select_template
      trip = Trip.includes(groups: [trip_destinations: :location]).find(params[:id])
      template_id = params[:preparation_template_id].presence

      trip.update(preparation_template_id: template_id, preparations_html: nil)

      content_html = trip.preparation_template&.content_html
      rendered = if content_html
        trip_json = build_trip_json(trip)
        Mustache.render(content_html, trip_json)
      else
        ""
      end

      render json: {
        status: :ok,
        rendered_html: rendered,
        template_name: trip.preparation_template&.name
      }
    end

    def build_trip_json(trip)
      TripJsonBuilder.build(trip)
    end

    def error_message(missing_locations)
      "Tych miejsc nie znaleziono:<br>" +
        missing_locations.each { |s| s.prepend("- ") }.join("<br>") +
        "<br>" \
        "Sprawdź, czy nie ma literówek lub dodaj brakujące miejsca do aplikacji."
    end

    def trip_params
      params.require(:trip).permit(:active, :admin_user_id, :date, :source_spreadsheet_url, :preparations_html, :preparation_template_id)
    end
  end
end
