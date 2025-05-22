class ModelFilesController < ApplicationController
  include ActionController::Live

  before_action :get_model
  before_action :get_file, except: [:create, :bulk_edit, :bulk_update]

  skip_after_action :verify_authorized, only: [:bulk_edit, :bulk_update]
  after_action :verify_policy_scoped, only: [:bulk_edit, :bulk_update]

  def configure_content_security_policy
    # If embed mode, allow any frame ancestor
    content_security_policy.frame_ancestors [:https, :http] if embedded?
  end

  def show
    if embedded?
      respond_to do |format|
        format.html { render "embedded", layout: "embed" }
      end
    elsif stale?(@file)
      @duplicates = @file.duplicates
      respond_to do |format|
        format.html
        format.manyfold_api_v0 { render json: ManyfoldApi::V0::ModelFileSerializer.new(@file).serialize }
        format.any(*SupportedMimeTypes.indexable_types.map(&:to_sym)) do
          send_file_content disposition: (params[:download] == "true") ? :attachment : :inline
        end
      end
    end
  end

  def create
    authorize @model
    if params[:convert]
      file = ModelFile.find_param(params[:convert][:id])
      file.convert_later params[:convert][:to]
      redirect_back_or_to [@model, file], notice: t(".conversion_started")
    elsif params[:uploads]
      uploads = begin
        JSON.parse(params[:uploads])
      rescue
        []
      end
      uploads.each do |upload|
        ProcessUploadedFileJob.perform_later(
          @model.library.id,
          upload,
          model: @model
        )
      end
      redirect_to @model, notice: t(".success")
    else
      head :unprocessable_entity
    end
  end

  def update
    result = @file.update(file_params)
    respond_to do |format|
      format.html do
        if result
          current_user.set_list_state(@file, :printed, params[:model_file][:printed] === "1")
          redirect_to [@model, @file], notice: t(".success")
        else
          render :edit, alert: t(".failure")
        end
      end
      format.manyfold_api_v0 do
        if result
          render json: ManyfoldApi::V0::ModelFileSerializer.new(@file).serialize
        else
          render json: @file.errors.to_json, status: :unprocessable_entity
        end
      end
    end
  end

  def bulk_edit
    @files = policy_scope(@model.model_files.without_special)
  end

  def bulk_update
    hash = bulk_update_params
    ids_to_update = params[:model_files].keep_if { |key, value| value == "1" }.keys
    files = policy_scope(@model.model_files.without_special).where(public_id: ids_to_update)
    files.each do |file|
      ActiveRecord::Base.transaction do
        current_user.set_list_state(file, :printed, params[:printed] === "1")
        options = {}
        if params[:pattern].present?
          options[:filename] =
            file.filename.split(file.extension).first.gsub(params[:pattern], params[:replacement]) +
            file.extension
        end
        file.update(hash.merge(options))
      end
    end
    if params[:split]
      new_model = @model.split! files: files
      redirect_to model_path(new_model), notice: t(".success")
    else
      redirect_back_or_to model_path(@model), notice: t(".success")
    end
  end

  def destroy
    authorize @file
    @file.delete_from_disk_and_destroy
    respond_to do |format|
      format.html do
        if request.referer && (URI.parse(request.referer).path == model_model_file_path(@model, @file))
          # If we're coming from the file page itself, we can't go back there
          redirect_to model_path(@model), notice: t(".success")
        else
          redirect_back_or_to model_path(@model), notice: t(".success")
        end
      end
      format.manyfold_api_v0 { head :no_content }
    end
  end

  private

  def send_file_content(disposition: :attachment)
    # Check if we can send a direct URL
    redirect_to(@file.attachment.url, allow_other_host: true) if /https?:\/\//.match?(@file.attachment.url)
    # Otherwise provide a direct download
    status, headers, body = @file.attachment.to_rack_response(disposition: disposition)
    self.status = status
    self.headers.merge!(headers)
    self.response_body = body
  rescue Errno::ENOENT
    head :internal_server_error
  end

  def bulk_update_params
    params.permit(
      :presupported,
      :y_up,
      :previewable
    ).compact_blank
  end

  def file_params
    if is_api_request?
      raise ActionController::BadRequest unless params[:json]
      ManyfoldApi::V0::ModelFileDeserializer.new(params[:json]).deserialize
    else
      Form::ModelFileDeserializer.new(params).deserialize
    end
  end

  def get_model
    @model = Model.find_param(params[:model_id])
  end

  def get_file
    # Check for signed download URLs
    if has_signed_id?
      @file = @model.model_files.find_signed!(params[:id], purpose: "download")
      skip_authorization
    else
      scope = policy_scope(@model.model_files)
      begin
        @file = scope.find_param(params[:id])
      rescue ActiveRecord::RecordNotFound
        @file = scope.find_by!(filename: [params[:id], params[:format]].join("."))
      end
      authorize @file
    end
    @title = @file.name
  rescue ActiveSupport::MessageVerifier::InvalidSignature
    raise ActiveRecord::RecordNotFound
  end

  def embedded?
    params[:embed] == "true"
  end
end
