use_s3_caching false
append_timestamp false
s3_access_key  ENV['AWS_ACCESS_KEY_ID']
s3_secret_key  ENV['AWS_SECRET_ACCESS_KEY']
s3_bucket      ENV['AWS_OMNIBUS_CACHE_S3_BUCKET']

build_retries 1
