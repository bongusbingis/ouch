-- Retry and refresh intervals for server-backed client views, in seconds.
--!strict

return {
	TimeoutSeconds = 8,
	InitialRetrySeconds = 1,
	MaxRetrySeconds = 15,
	RefreshSeconds = 30,
}
