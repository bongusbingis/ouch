-- Cloud publication requires an executed suite with no test or planning errors.
--!strict

return function(passed: number, failed: number, failureMessages: { string })
	if failed > 0 or #failureMessages > 0 then
		error(
			string.format("cloud tests: %d failing spec(s), %d error(s); see logs above", failed, #failureMessages),
			0
		)
	end
	if passed == 0 then
		error("cloud tests: no tests passed; the suite was empty or fully skipped", 0)
	end
end
